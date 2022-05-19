#!/bin/bash

cluster1_context="cluster1"

kubectl delete -f ../cluster1/4.4.a.security-rate-limiting.yaml --context ${cluster1_context}

kubectl apply -f ../cluster1/2.1.b-routing-tls-single-upstream.yaml --context ${cluster1_context}