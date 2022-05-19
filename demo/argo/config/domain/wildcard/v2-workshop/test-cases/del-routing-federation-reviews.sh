#!/bin/bash

cluster1_context="cluster1"

kubectl delete -f ../cluster1/2.2.b-routing-federation-reviews.yaml --context ${cluster1_context}