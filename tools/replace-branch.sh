# tested on macos
#/bin/bash
github_branch=''$1''

# check to see if github branch variable was passed through, if not prompt for it
if [[ ${github_branch} == "" ]]
  then
    # provide github branch
    echo "Please provide the GitHub branch you want to use:"
    read github_branch
fi

# sed commands to replace github_branch variable

#platform-owners/cluster1
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster1/cluster1-apps.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster1/cluster1-cluster-config.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster1/cluster1-infra.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster1/cluster1-mesh-config.yaml

#platform-owners/cluster2
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster2/cluster2-apps.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster2/cluster2-cluster-config.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster2/cluster2-infra.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster2/cluster2-mesh-config.yaml

#platform-owners/cluster3
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster3/cluster3-apps.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster3/cluster3-cluster-config.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster3/cluster3-infra.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/cluster3/cluster3-mesh-config.yaml

#platform-owners/mgmt
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/mgmt/mgmt-apps.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/mgmt/mgmt-cluster-config.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/mgmt/mgmt-infra.yaml
sed -i '' -e 's/HEAD/'${github_branch}'/g' ../platform-owners/mgmt/mgmt-mesh-config.yaml