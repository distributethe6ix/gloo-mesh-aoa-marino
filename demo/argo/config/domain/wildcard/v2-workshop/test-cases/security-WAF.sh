#!/bin/bash

cluster1_context="cluster1"

kubectl apply -f ../cluster1/4.5.a-WAF-policy.yaml --context ${cluster1_context}