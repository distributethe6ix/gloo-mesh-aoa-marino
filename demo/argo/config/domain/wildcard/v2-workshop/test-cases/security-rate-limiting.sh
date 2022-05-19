#!/bin/bash

cluster1_context="cluster1"

kubectl apply -f ../cluster1/4.4.a.security-rate-limiting.yaml --context ${cluster1_context}