#!/bin/bash

# author: Amir Ghaffari
# @RELEASE project (http://www.release-project.eu


############## Sleep times
Sleep_first_Riak_node=60; # Installation of other Riak nodes start with 2 minutes delay to give enough time to the first Riak node for accepting cluster join requests
Sleep_other_Riak_node=5; # Installation of each Riak node (except the first one) starts with 5 seconds delay to give enough time Riak cluster copes with new node requests
Sleep_to_Install_Riak_Nodes=420; # giving 7 minutes to finish the Riak installation
Sleep_to_Get_Stable_per_node=6; # giving 3 minutes to get to a stable condition
Sleep_after_short_bench_per_node=10; # giving 6 minutes to get to a stable condition after a short data injection to the cluster
Sleep_to_Delay_Copy_Bash_Bench=2; # to avoid traffic congestion for copying Basho Bench on all generator nodes
Sleep_to_get_finish_Elastisity=120; #  2 minutes to become sure that everything finishes
########################### End of sleep times
