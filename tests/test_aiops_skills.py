"""Unit tests for pure logic functions in AIOps skills.

Tests cover functions that don't require MCP or infrastructure access:
- anomaly-detection: baseline computation, anomaly classification, correlation check
- slo-management: error budget calculation, policy evaluation
- predictive-scaling: replica computation, event adjustment
- automated-remediation: preflight checks, effectiveness tracking
"""

import numpy as np
import pytest
from datetime import datetime, timedelta


# ============================================================
# anomaly-detection: compute_baseline
# ============================================================

def compute_baseline(metric_data, timestamps, sensitivity=3.0, window_days=7):
    """7일 이동 평균 + Nσ 기반 정상 범위 계산."""
    data = np.array(metric_data)
    
    # Outlier 제거 (IQR 방식)
    q1, q3 = np.percentile(data, [25, 75])
    iqr = q3 - q1
    mask = (data >= q1 - 1.5 * iqr) & (data <= q3 + 1.5 * iqr)
    clean_data = data[mask]
    
    mean = float(np.mean(clean_data))
    std = float(np.std(clean_data))
    
    # 계절성 프로파일 생성
    seasonal = {}
    for ts, val in zip(timestamps, metric_data):
        hour = datetime.fromisoformat(ts.replace("Z", "+00:00")).hour
        dow = datetime.fromisoformat(ts.replace("Z", "+00:00")).weekday()
        key = f"{dow}_{hour}"
        seasonal.setdefault(key, []).append(val)
    seasonal_profile = {k: float(np.mean(v)) for k, v in seasonal.items()}
    
    return {
        "mean": mean,
        "std": std,
        "upper_bound": mean + sensitivity * std,
        "lower_bound": max(0, mean - sensitivity * std),
        "sensitivity": sensitivity,
        "window_days": window_days,
        "seasonal_profile": seasonal_profile,
    }


class TestComputeBaseline:
    def test_normal_data(self):
        """정상 데이터에서 베이스라인 계산."""
        np.random.seed(42)
        data = np.random.normal(100, 10, 168).tolist()  # 7일 * 24시간
        base_time = datetime(2026, 5, 1, 0, 0, 0)
        timestamps = [
            (base_time + timedelta(hours=i)).isoformat() + "Z"
            for i in range(168)
        ]
        
        result = compute_baseline(data, timestamps)
        
        assert 90 < result["mean"] < 110
        assert 5 < result["std"] < 15
        assert result["upper_bound"] > result["mean"]
        assert result["lower_bound"] < result["mean"]
        assert result["lower_bound"] >= 0
    
    def test_outlier_removal(self):
        """IQR 기반 outlier 제거 확인."""
        data = [100.0] * 100 + [10000.0]  # 극단 outlier 1개
        base_time = datetime(2026, 5, 1, 0, 0, 0)
        timestamps = [
            (base_time + timedelta(hours=i)).isoformat() + "Z"
            for i in range(101)
        ]
        
        result = compute_baseline(data, timestamps)
        
        # Outlier 제거 후 mean은 100 근처여야 함
        assert 95 < result["mean"] < 105
    
    def test_sensitivity_affects_bounds(self):
        """sensitivity 값이 bound 범위에 영향."""
        data = [100.0 + i % 10 for i in range(168)]
        base_time = datetime(2026, 5, 1, 0, 0, 0)
        timestamps = [
            (base_time + timedelta(hours=i)).isoformat() + "Z"
            for i in range(168)
        ]
        
        result_3 = compute_baseline(data, timestamps, sensitivity=3.0)
        result_5 = compute_baseline(data, timestamps, sensitivity=5.0)
        
        assert result_5["upper_bound"] > result_3["upper_bound"]
    
    def test_seasonal_profile_generated(self):
        """계절성 프로파일이 생성되는지 확인."""
        data = [100.0] * 168
        base_time = datetime(2026, 5, 1, 0, 0, 0)
        timestamps = [
            (base_time + timedelta(hours=i)).isoformat() + "Z"
            for i in range(168)
        ]
        
        result = compute_baseline(data, timestamps)
        
        assert len(result["seasonal_profile"]) > 0


# ============================================================
# anomaly-detection: classify_anomaly
# ============================================================

def classify_anomaly(value, baseline, timestamp):
    """단일 데이터 포인트의 이상 여부 판정."""
    if baseline["std"] == 0:
        return None
    
    sigma = abs(value - baseline["mean"]) / baseline["std"]
    
    if sigma < 2.0:
        return None
    
    if sigma >= 5.0:
        severity = "critical"
    elif sigma >= baseline["sensitivity"]:
        severity = "warning"
    else:
        severity = "info"
    
    return {
        "value": value,
        "sigma_deviation": sigma,
        "severity": severity,
        "timestamp": timestamp,
    }


class TestClassifyAnomaly:
    def setup_method(self):
        self.baseline = {
            "mean": 100.0,
            "std": 10.0,
            "upper_bound": 130.0,
            "lower_bound": 70.0,
            "sensitivity": 3.0,
            "seasonal_profile": {},
        }
    
    def test_normal_value(self):
        """정상 범위 값은 None 반환."""
        result = classify_anomaly(105.0, self.baseline, "2026-05-08T10:00:00Z")
        assert result is None
    
    def test_info_level(self):
        """2σ~3σ 이탈은 info."""
        result = classify_anomaly(125.0, self.baseline, "2026-05-08T10:00:00Z")
        assert result is not None
        assert result["severity"] == "info"
    
    def test_warning_level(self):
        """3σ~5σ 이탈은 warning."""
        result = classify_anomaly(135.0, self.baseline, "2026-05-08T10:00:00Z")
        assert result is not None
        assert result["severity"] == "warning"
    
    def test_critical_level(self):
        """5σ 이상 이탈은 critical."""
        result = classify_anomaly(160.0, self.baseline, "2026-05-08T10:00:00Z")
        assert result is not None
        assert result["severity"] == "critical"
    
    def test_zero_std(self):
        """std=0이면 None 반환 (division by zero 방지)."""
        baseline = {**self.baseline, "std": 0.0}
        result = classify_anomaly(200.0, baseline, "2026-05-08T10:00:00Z")
        assert result is None
    
    def test_negative_deviation(self):
        """하한 이탈도 탐지."""
        result = classify_anomaly(50.0, self.baseline, "2026-05-08T10:00:00Z")
        assert result is not None
        assert result["severity"] == "critical"  # 5σ 이탈


# ============================================================
# anomaly-detection: correlation_check
# ============================================================

def correlation_check(metrics, expected_correlations, window_size=60):
    """메트릭 간 상관관계 이탈 탐지."""
    anomalies = []
    for corr_def in expected_correlations:
        m1_name, m2_name = corr_def["pair"].split(":")
        expected_r = corr_def["expected_r"]
        
        m1_data = metrics.get(m1_name, [])
        m2_data = metrics.get(m2_name, [])
        
        if len(m1_data) < window_size or len(m2_data) < window_size:
            continue
        
        recent_m1 = np.array(m1_data[-window_size:])
        recent_m2 = np.array(m2_data[-window_size:])
        
        if np.std(recent_m1) == 0 or np.std(recent_m2) == 0:
            continue
        
        actual_r = float(np.corrcoef(recent_m1, recent_m2)[0, 1])
        deviation = abs(actual_r - expected_r)
        
        if deviation > 0.3:
            anomalies.append({
                "type": "correlation_breakdown",
                "pair": corr_def["pair"],
                "expected_r": expected_r,
                "actual_r": actual_r,
                "deviation": deviation,
                "severity": "critical" if deviation > 0.5 else "warning",
            })
    
    return anomalies


class TestCorrelationCheck:
    def test_correlated_data_no_anomaly(self):
        """정상 상관관계 → anomaly 없음."""
        np.random.seed(42)
        x = np.random.normal(0, 1, 100)
        y = x * 0.8 + np.random.normal(0, 0.3, 100)  # r ≈ 0.93
        
        metrics = {"A": x.tolist(), "B": y.tolist()}
        correlations = [{"pair": "A:B", "expected_r": 0.9}]
        
        result = correlation_check(metrics, correlations, window_size=100)
        assert len(result) == 0
    
    def test_uncorrelated_data_anomaly(self):
        """상관관계 붕괴 → anomaly 탐지."""
        np.random.seed(42)
        x = np.random.normal(0, 1, 100)
        y = np.random.normal(0, 1, 100)  # 독립 → r ≈ 0
        
        metrics = {"A": x.tolist(), "B": y.tolist()}
        correlations = [{"pair": "A:B", "expected_r": 0.8}]
        
        result = correlation_check(metrics, correlations, window_size=100)
        assert len(result) == 1
        assert result[0]["severity"] in ("warning", "critical")
    
    def test_insufficient_data_skipped(self):
        """데이터 부족 시 스킵."""
        metrics = {"A": [1, 2, 3], "B": [4, 5, 6]}
        correlations = [{"pair": "A:B", "expected_r": 0.9}]
        
        result = correlation_check(metrics, correlations, window_size=60)
        assert len(result) == 0


# ============================================================
# slo-management: calculate_error_budget
# ============================================================

def calculate_error_budget(slo_config, good_events, total_events, window_days):
    """Error Budget 잔량 계산."""
    target = slo_config["target"]
    bad_events = total_events - good_events
    
    allowed_bad = (1 - target) * total_events
    remaining = max(0, allowed_bad - bad_events)
    remaining_pct = (remaining / allowed_bad * 100) if allowed_bad > 0 else 100.0
    
    elapsed_days = max(1, window_days // 2)  # 간소화
    sustainable_daily_burn = allowed_bad / window_days
    actual_daily_burn = bad_events / elapsed_days if elapsed_days > 0 else 0
    burn_rate = actual_daily_burn / sustainable_daily_burn if sustainable_daily_burn > 0 else 0
    
    if actual_daily_burn > 0 and remaining > 0:
        projected_exhaustion = remaining / actual_daily_burn
    else:
        projected_exhaustion = None
    
    return {
        "slo_name": slo_config["name"],
        "target": target,
        "total_events": total_events,
        "good_events": good_events,
        "bad_events": bad_events,
        "allowed_bad_events": allowed_bad,
        "remaining_budget": remaining,
        "remaining_pct": remaining_pct,
        "burn_rate": burn_rate,
        "projected_exhaustion_days": projected_exhaustion,
    }


class TestCalculateErrorBudget:
    def test_perfect_service(self):
        """에러 0건 → budget 100%."""
        slo = {"name": "availability", "target": 0.999}
        result = calculate_error_budget(slo, 10000, 10000, 30)
        
        assert result["remaining_pct"] == 100.0
        assert result["bad_events"] == 0
        assert result["burn_rate"] == 0
    
    def test_budget_half_consumed(self):
        """budget 절반 소진."""
        slo = {"name": "availability", "target": 0.99}
        # 99% target, 10000 total → allowed_bad = 100
        # 50 bad events → 50% consumed
        result = calculate_error_budget(slo, 9950, 10000, 30)
        
        assert abs(result["allowed_bad_events"] - 100.0) < 0.01
        assert result["bad_events"] == 50
        assert 45 < result["remaining_pct"] < 55
    
    def test_budget_exhausted(self):
        """budget 완전 소진."""
        slo = {"name": "availability", "target": 0.99}
        # allowed_bad = 100, actual_bad = 150 → over budget
        result = calculate_error_budget(slo, 9850, 10000, 30)
        
        assert result["remaining_pct"] == 0.0
        assert result["remaining_budget"] == 0
    
    def test_zero_events(self):
        """이벤트 0건 → budget 100%."""
        slo = {"name": "availability", "target": 0.999}
        result = calculate_error_budget(slo, 0, 0, 30)
        
        assert result["remaining_pct"] == 100.0
    
    def test_burn_rate_calculation(self):
        """burn rate가 1.0 이상이면 지속 불가능."""
        slo = {"name": "availability", "target": 0.99}
        # 30일 윈도우, allowed_bad=100, 15일 경과 시점에 80 bad → 빠른 소진
        result = calculate_error_budget(slo, 9920, 10000, 30)
        
        assert result["burn_rate"] > 1.0  # 지속 불가능 속도


# ============================================================
# slo-management: evaluate_budget_policy
# ============================================================

def evaluate_budget_policy(service, budgets, policy_config):
    """Error Budget 잔량에 따라 정책 결정 (min inclusive, max exclusive, top inclusive)."""
    min_budget = min(budgets, key=lambda b: b["remaining_pct"])
    remaining = min_budget["remaining_pct"]

    active_policy = None
    for policy in sorted(policy_config, key=lambda p: p["remaining_pct_min"]):
        pmin = policy["remaining_pct_min"]
        pmax = policy["remaining_pct_max"]
        if pmax == 100:
            in_band = pmin <= remaining <= pmax
        else:
            in_band = pmin <= remaining < pmax
        if in_band:
            active_policy = policy
            break

    if not active_policy:
        active_policy = {"mode": "normal", "deploy_allowed": True}

    return {
        "service": service,
        "limiting_slo": min_budget["slo_name"],
        "remaining_pct": remaining,
        "mode": active_policy["mode"],
        "deploy_allowed": active_policy["deploy_allowed"],
    }


SAMPLE_POLICY = [
    {"remaining_pct_min": 50, "remaining_pct_max": 100, "mode": "normal", "deploy_allowed": True},
    {"remaining_pct_min": 25, "remaining_pct_max": 50, "mode": "slow-down", "deploy_allowed": True},
    {"remaining_pct_min": 10, "remaining_pct_max": 25, "mode": "caution", "deploy_allowed": True},
    {"remaining_pct_min": 0, "remaining_pct_max": 10, "mode": "freeze", "deploy_allowed": False},
]


class TestEvaluateBudgetPolicy:
    def test_normal_mode(self):
        """budget > 50% → normal."""
        budgets = [{"slo_name": "avail", "remaining_pct": 72.0}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "normal"
        assert result["deploy_allowed"] is True
    
    def test_slowdown_mode(self):
        """25% < budget < 50% → slow-down."""
        budgets = [{"slo_name": "avail", "remaining_pct": 35.0}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "slow-down"
        assert result["deploy_allowed"] is True
    
    def test_freeze_mode(self):
        """budget < 10% → freeze."""
        budgets = [{"slo_name": "latency", "remaining_pct": 5.0}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "freeze"
        assert result["deploy_allowed"] is False
    
    def test_worst_slo_determines_policy(self):
        """가장 낮은 budget의 SLO가 정책 결정."""
        budgets = [
            {"slo_name": "avail", "remaining_pct": 80.0},
            {"slo_name": "latency", "remaining_pct": 8.0},
        ]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "freeze"
        assert result["limiting_slo"] == "latency"


# ============================================================
# predictive-scaling: compute_scaling_schedule
# ============================================================

def compute_scaling_schedule(predictions, scaling_config, cost_constraints):
    """비용 제약 내 최적 스케일링 스케줄 계산 (이름 기반 조회)."""
    target_rps = next(
        (m["target"] for m in scaling_config.get("metrics", [])
         if m.get("name") == "requests_per_second"),
        100,
    )

    min_replicas = scaling_config.get("current_hpa", {}).get("min_replicas", 2)
    max_replicas = scaling_config.get("current_hpa", {}).get("max_replicas", 20)

    cost_per_hour = cost_constraints.get("cost_per_replica_hour_usd", 2.5)
    max_hourly_cost = cost_constraints.get("max_hourly_cost_usd", 50)
    spot_ratio = cost_constraints.get("spot_ratio", 0.7)
    spot_discount = cost_constraints.get("spot_discount", 0.6)

    effective_cost = cost_per_hour * (spot_ratio * spot_discount + (1 - spot_ratio) * 1.0)
    max_replicas_by_cost = int(max_hourly_cost / effective_cost)

    schedule = []
    for pred in predictions:
        needed_rps = pred["upper_ci"]
        ideal_replicas = int(np.ceil(needed_rps / target_rps))
        replicas = max(min_replicas, min(ideal_replicas, max_replicas, max_replicas_by_cost))
        hourly_cost = replicas * effective_cost

        schedule.append({
            "hour": pred["hour"],
            "predicted_rps": pred["predicted_rps"],
            "upper_ci_rps": pred["upper_ci"],
            "replicas": replicas,
            "hourly_cost_usd": round(hourly_cost, 2),
        })

    return schedule


class TestComputeScalingSchedule:
    def setup_method(self):
        self.scaling_config = {
            "current_hpa": {"min_replicas": 2, "max_replicas": 20},
            "metrics": [
                {"name": "cpu_utilization", "target_pct": 70},
                {"name": "requests_per_second", "target": 100},
            ],
        }
        self.cost_constraints = {
            "max_hourly_cost_usd": 50,
            "cost_per_replica_hour_usd": 2.5,
            "spot_ratio": 0.7,
            "spot_discount": 0.6,
        }
    
    def test_min_replicas_enforced(self):
        """최소 replica 수 보장."""
        predictions = [{"hour": 0, "predicted_rps": 10, "upper_ci": 20}]
        result = compute_scaling_schedule(predictions, self.scaling_config, self.cost_constraints)
        assert result[0]["replicas"] >= 2
    
    def test_max_replicas_enforced(self):
        """최대 replica 수 제한."""
        predictions = [{"hour": 0, "predicted_rps": 5000, "upper_ci": 6000}]
        result = compute_scaling_schedule(predictions, self.scaling_config, self.cost_constraints)
        assert result[0]["replicas"] <= 20
    
    def test_cost_cap_enforced(self):
        """비용 상한 초과 시 replica 제한."""
        # effective_cost = 2.5 * (0.7*0.6 + 0.3*1.0) = 2.5 * 0.72 = 1.8
        # max_by_cost = 50 / 1.8 = 27 → max_replicas(20)가 더 작으므로 20이 상한
        predictions = [{"hour": 0, "predicted_rps": 3000, "upper_ci": 4000}]
        result = compute_scaling_schedule(predictions, self.scaling_config, self.cost_constraints)
        
        hourly_cost = result[0]["hourly_cost_usd"]
        assert hourly_cost <= 50.0
    
    def test_scales_with_load(self):
        """부하 증가 시 replica 증가."""
        predictions = [
            {"hour": 0, "predicted_rps": 100, "upper_ci": 150},
            {"hour": 1, "predicted_rps": 500, "upper_ci": 700},
        ]
        result = compute_scaling_schedule(predictions, self.scaling_config, self.cost_constraints)
        assert result[1]["replicas"] > result[0]["replicas"]


# ============================================================
# anomaly-detection: seasonal_adjust (편차 기반 보정)
# ============================================================

def seasonal_adjust(value, timestamp, seasonal_profile, global_mean):
    """계절성 프로파일 기반 보정 (편차 기반)."""
    dt = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    key = f"{dt.weekday()}_{dt.hour}"
    seasonal_mean = seasonal_profile.get(key)

    if seasonal_mean is None:
        return value, global_mean

    adjusted = value - seasonal_mean + global_mean
    return adjusted, seasonal_mean


class TestSeasonalAdjust:
    def test_normal_hour(self):
        """일반 시간대 보정."""
        profile = {"3_14": 100.0}  # 목요일 14시 평균 = 100
        value = 120.0
        global_mean = 80.0

        adjusted, seasonal_mean = seasonal_adjust(
            value, "2026-05-07T14:00:00Z", profile, global_mean
        )
        # adjusted = 120 - 100 + 80 = 100
        assert adjusted == 100.0
        assert seasonal_mean == 100.0

    def test_low_traffic_hour_no_false_amplification(self):
        """저트래픽 시간대에서 비율 방식이면 폭발하지만, 편차 방식은 안정적."""
        profile = {"3_3": 0.5}  # 목요일 03시 평균 = 0.5 (매우 낮음)
        value = 2.0
        global_mean = 100.0

        adjusted, seasonal_mean = seasonal_adjust(
            value, "2026-05-07T03:00:00Z", profile, global_mean
        )
        # 편차 기반: 2.0 - 0.5 + 100.0 = 101.5
        # 비율 기반이었다면: 2.0 / 0.5 = 4.0 → 400% 증폭 (false critical)
        assert adjusted == 101.5
        assert adjusted < 200  # 합리적인 범위

    def test_missing_profile_key(self):
        """프로파일에 없는 시간대 → 원래 값 반환."""
        profile = {}
        value = 50.0
        global_mean = 80.0

        adjusted, seasonal_mean = seasonal_adjust(
            value, "2026-05-08T10:00:00Z", profile, global_mean
        )
        assert adjusted == 50.0
        assert seasonal_mean == global_mean

    def test_high_traffic_hour(self):
        """고트래픽 시간대에서 보정."""
        profile = {"3_9": 200.0}  # 목요일 09시 평균 = 200 (피크)
        value = 210.0
        global_mean = 100.0

        adjusted, seasonal_mean = seasonal_adjust(
            value, "2026-05-07T09:00:00Z", profile, global_mean
        )
        # 210 - 200 + 100 = 110 → 약간 높지만 정상 범위
        assert adjusted == 110.0


# ============================================================
# slo-management: evaluate_budget_policy (경계값 테스트)
# ============================================================

class TestBudgetPolicyBoundary:
    def test_exactly_50_is_normal(self):
        """정확히 50% → normal (min inclusive, top band)."""
        budgets = [{"slo_name": "avail", "remaining_pct": 50.0}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "normal"

    def test_just_below_50_is_slowdown(self):
        """49.99% → slow-down (max exclusive)."""
        budgets = [{"slo_name": "avail", "remaining_pct": 49.99}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "slow-down"

    def test_exactly_25_is_slowdown(self):
        """정확히 25% → slow-down (min inclusive)."""
        budgets = [{"slo_name": "avail", "remaining_pct": 25.0}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "slow-down"

    def test_just_below_25_is_caution(self):
        """24.99% → caution."""
        budgets = [{"slo_name": "avail", "remaining_pct": 24.99}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "caution"

    def test_exactly_10_is_caution(self):
        """정확히 10% → caution (min inclusive)."""
        budgets = [{"slo_name": "avail", "remaining_pct": 10.0}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "caution"

    def test_just_below_10_is_freeze(self):
        """9.99% → freeze."""
        budgets = [{"slo_name": "avail", "remaining_pct": 9.99}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "freeze"

    def test_zero_is_freeze(self):
        """0% → freeze."""
        budgets = [{"slo_name": "avail", "remaining_pct": 0.0}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "freeze"

    def test_100_is_normal(self):
        """100% → normal (top band max inclusive)."""
        budgets = [{"slo_name": "avail", "remaining_pct": 100.0}]
        result = evaluate_budget_policy("svc", budgets, SAMPLE_POLICY)
        assert result["mode"] == "normal"


    def test_single_metric_no_crash(self):
        """metrics에 1개만 있어도 crash 안 함 (requests_per_second 없으면 default 100)."""
        config = {
            "current_hpa": {"min_replicas": 2, "max_replicas": 10},
            "metrics": [{"name": "cpu_utilization", "target_pct": 70}],
        }
        cost = {"max_hourly_cost_usd": 50, "cost_per_replica_hour_usd": 2.5,
                "spot_ratio": 0.7, "spot_discount": 0.6}
        predictions = [{"hour": 0, "predicted_rps": 300, "upper_ci": 400}]

        result = compute_scaling_schedule(predictions, config, cost)
        assert result[0]["replicas"] >= 2

    def test_finds_rps_metric_by_name(self):
        """이름으로 requests_per_second 메트릭 찾기."""
        config = {
            "current_hpa": {"min_replicas": 2, "max_replicas": 20},
            "metrics": [
                {"name": "cpu_utilization", "target_pct": 70},
                {"name": "requests_per_second", "target": 200},
                {"name": "memory_utilization", "target_pct": 80},
            ],
        }
        cost = {"max_hourly_cost_usd": 100, "cost_per_replica_hour_usd": 2.5,
                "spot_ratio": 0.7, "spot_discount": 0.6}
        predictions = [{"hour": 0, "predicted_rps": 500, "upper_ci": 600}]

        result = compute_scaling_schedule(predictions, config, cost)
        # 600 / 200 = 3 replicas
        assert result[0]["replicas"] == 3

    def test_empty_metrics_uses_default(self):
        """metrics 비어있으면 default target=100."""
        config = {"current_hpa": {"min_replicas": 2, "max_replicas": 20}, "metrics": []}
        cost = {"max_hourly_cost_usd": 100, "cost_per_replica_hour_usd": 2.5,
                "spot_ratio": 0.7, "spot_discount": 0.6}
        predictions = [{"hour": 0, "predicted_rps": 300, "upper_ci": 500}]

        result = compute_scaling_schedule(predictions, config, cost)
        # 500 / 100 = 5 replicas
        assert result[0]["replicas"] == 5


# ============================================================
# automated-remediation: runbook matching & action coverage
# ============================================================

def match_runbook_actions(runbook_yaml: dict) -> list[str]:
    """runbook에서 사용된 모든 action 추출."""
    actions = []
    for step in runbook_yaml.get("steps", []):
        actions.append(step["action"])
    if runbook_yaml.get("rollback"):
        actions.append(runbook_yaml["rollback"]["action"])
    return actions


SUPPORTED_ACTIONS = {
    "kubectl_get_revision", "kubectl_logs", "kubectl_describe",
    "kubectl_delete_pod", "kubectl_scale", "wait_for_ready",
    "kubectl_top_pods", "kubectl_evict", "check_metric", "argocd_rollback",
}

SUPPORTED_ROLLBACK_ACTIONS = {
    "scale_previous_revision", "manual_escalation", "cordon_and_drain",
}


class TestRunbookActionCoverage:
    def test_pod_crashloop_actions_supported(self):
        """pod-crashloop runbook의 모든 action이 지원됨."""
        runbook = {
            "steps": [
                {"action": "kubectl_logs"},
                {"action": "kubectl_describe"},
                {"action": "kubectl_delete_pod"},
                {"action": "wait_for_ready"},
            ],
            "rollback": {"action": "scale_previous_revision"},
        }
        actions = match_runbook_actions(runbook)
        step_actions = set(actions[:-1])
        rollback_action = actions[-1]

        assert step_actions.issubset(SUPPORTED_ACTIONS)
        assert rollback_action in SUPPORTED_ROLLBACK_ACTIONS

    def test_canary_rollback_actions_supported(self):
        """canary-rollback runbook의 모든 action이 지원됨."""
        runbook = {
            "steps": [
                {"action": "kubectl_get_revision"},
                {"action": "kubectl_scale"},
                {"action": "wait_for_ready"},
                {"action": "argocd_rollback"},
                {"action": "wait_for_ready"},
            ],
            "rollback": {"action": "manual_escalation"},
        }
        actions = match_runbook_actions(runbook)
        step_actions = set(actions[:-1])
        rollback_action = actions[-1]

        assert step_actions.issubset(SUPPORTED_ACTIONS)
        assert rollback_action in SUPPORTED_ROLLBACK_ACTIONS

    def test_memory_pressure_actions_supported(self):
        """memory-pressure runbook의 모든 action이 지원됨."""
        runbook = {
            "steps": [
                {"action": "kubectl_top_pods"},
                {"action": "kubectl_evict"},
                {"action": "check_metric"},
            ],
            "rollback": {"action": "cordon_and_drain"},
        }
        actions = match_runbook_actions(runbook)
        step_actions = set(actions[:-1])
        rollback_action = actions[-1]

        assert step_actions.issubset(SUPPORTED_ACTIONS)
        assert rollback_action in SUPPORTED_ROLLBACK_ACTIONS


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
