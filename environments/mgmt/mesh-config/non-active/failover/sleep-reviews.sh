kubectl --context cluster1 patch deploy reviews-v1 --patch '{"spec": {"template": {"spec": {"containers": [{"name": "reviews","command": ["sleep", "20h"]}]}}}}'

# k edit deploy reviews-v1 --context cluster1