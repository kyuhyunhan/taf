#!/bin/bash
# G3-C6 — CloudWatch alarms in template.yaml
set -uo pipefail
TPL="$WORKDIR/server/template.yaml"
[[ -f "$TPL" ]] || exit 0
ALARM_COUNT=$(grep -c 'Type: AWS::CloudWatch::Alarm' "$TPL")
[[ "$ALARM_COUNT" -lt 3 ]] && exit 0
# Check for SNS subscription
if grep -q 'SNS::Topic\|SNS::Subscription' "$TPL"; then
    exit 3
fi
exit 2
