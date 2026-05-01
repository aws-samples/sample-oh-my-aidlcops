package oma

# Reference policy — rejects Deployments that claim approval_state="approved"
# without a populated approval_chain. Matches the enforcement wired into
# `oma compile --strict-enterprise` (v0.5). Operators can copy this file and
# tune the required role list for their organisation.

default deny := []

deny contains msg if {
    input.approval_state == "approved"
    count(input.approval_chain) == 0
    msg := sprintf(
        "deployment %q: approval_state=approved requires a non-empty approval_chain",
        [input.id]
    )
}

deny contains msg if {
    input.approval_state == "approved"
    some link in input.approval_chain
    link.reason == ""
    msg := sprintf(
        "deployment %q: approval_chain entry from %q has an empty reason",
        [input.id, link.approver]
    )
}
