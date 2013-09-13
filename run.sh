#!/bin/bash 

# author: Amir Ghaffari
# @RELEASE project (http://www.release-project.eu/)

# sleep-time definition is included
source constant.sh

BwlfCluster=true; # Specifies whether the benchmark use Heriot-Watt University's beowulf cluster or use Uppsala University's kalkyl cluster
Benchmark_length_minutes=10; # benchmark's duration in minute
Generators_per_Riak_node=3; # e.g. 2 means there are one traffic generator node per 2 Riak nodes
Start_Node=1;


#declare -a Riak_Versions=('riak-1.1.1' 'riak-1.2.0' 'riak-1.3.0' 'riak-1.3.2' 'riak-1.4.0')

declare -a Riak_Versions=('riak-1.4.0')  # specifies which Riak versions will be used in the benchmark

for Riak_version in ${Riak_Versions[@]}
do
	# Specifies how many experiment is needed
	for experiment in  1 # 1 2 3
	do     


		num_excepted_riak_nodes=0;
		#Do_not_send_command= (3 5 7 9 11 13);  # This is used for Elastisity benchmarking. These nodes will go down and then come up after a while
		String_Do_not_send_command="";
		for i in "${Do_not_send_command[@]}"
		do
			let num_excepted_riak_nodes=$num_excepted_riak_nodes+1
			if [ ${num_excepted_riak_nodes} -eq 1 ] ; then
				String_Do_not_send_command="$i";
			else
				String_Do_not_send_command="$String_Do_not_send_command;$i";
			fi
		done

		if [ -z "$String_Do_not_send_command" ]; then 
			String_Do_not_send_command="empty"
		fi

		for Number_of_Riak_Nodes in 9 # 10 20 30 40
		do     
			# calculate the number of traffic generator nodes based on number of Riak nodes
			let Number_of_Generator_Nodes=($Number_of_Riak_Nodes/$Generators_per_Riak_node);
			let temp=$Number_of_Generator_Nodes*$Generators_per_Riak_node;

			if [ $Number_of_Generator_Nodes -eq 0 ] ; then
				Number_of_Generator_Nodes=1;
			else
				if [ $Number_of_Riak_Nodes -ne $temp ] ; then
					let Number_of_Generator_Nodes=$Number_of_Generator_Nodes+1
				fi
			fi

			let Total_nodes=$Number_of_Riak_Nodes+$Number_of_Generator_Nodes;

			if $BwlfCluster ; then
				chmod 755 experiment.sh
				./experiment.sh $Number_of_Riak_Nodes $Number_of_Generator_Nodes $String_Do_not_send_command  $BwlfCluster $experiment $Benchmark_length_minutes $Start_Node $Riak_version;
			else
				let Total_cores=Total_nodes*8;
				if [ $num_excepted_riak_nodes -gt 0 ] ; then
					let NewBenchmark_length_minutes=$Benchmark_length_minutes*3+4*$num_excepted_riak_nodes;
				else
					NewBenchmark_length_minutes=$Benchmark_length_minutes
				fi
				let NewBenchmark_length_seconds=$NewBenchmark_length_minutes*60;
				let Aggregating_csv_files=20*$Total_nodes; # 20 seconds per each node
				let Sleep_after_short_bench=$Number_of_Riak_Nodes*$Sleep_after_short_bench_per_node;
				let Sleep_to_Get_Stable=$Number_of_Riak_Nodes*$Sleep_to_Get_Stable_per_node;
				# calculate how long the benchmark will take. We need this on clusters in which jobs must be run via a special resource manager software. On Kalkyl cluster, the SLURM software is used as a resource manager.
				let Total_benchmark_time_seconds=$Sleep_first_Riak_node+$Sleep_other_Riak_node*$Number_of_Riak_Nodes+$Sleep_to_Install_Riak_Nodes+$Sleep_to_Get_Stable+$Sleep_after_short_bench+$Sleep_to_Delay_Copy_Bash_Bench*$Number_of_Generator_Nodes+$Sleep_to_get_finish_Elastisity+$NewBenchmark_length_seconds+$Aggregating_csv_files;

				convertsecs() {
				 ((h=${1}/3600))
				 ((m=(${1}%3600)/60))
				 ((s=${1}%60))
				 printf "%02d:%02d:%02d\n" $h $m $s
				}
				Bench_time=$(convertsecs $Total_benchmark_time_seconds)

				String_format_sbatch="SBATCH -p node -N ${Total_nodes} -n ${Total_cores}"; # Applies calculated time and required resource, i.e. cores and nodes, into the experiment.sh file and create a new specific experiment file for this benchmark
				sed "s/SBATCH -p node -N 0 -n 0/$String_format_sbatch/g" experiment.sh>experiment_RiakNodes_${Number_of_Riak_Nodes}_generators_${Number_of_Generator_Nodes}_experiment_${experiment};
				sed -i "s/00:00:00/$Bench_time/g" experiment_RiakNodes_${Number_of_Riak_Nodes}_generators_${Number_of_Generator_Nodes}_experiment_${experiment};
				chmod 755 experiment_RiakNodes_${Number_of_Riak_Nodes}_generators_${Number_of_Generator_Nodes}_experiment_${experiment};
				## Submit and run an experiment
				sbatch    experiment_RiakNodes_${Number_of_Riak_Nodes}_generators_${Number_of_Generator_Nodes}_experiment_${experiment} $Number_of_Riak_Nodes $Number_of_Generator_Nodes $String_Do_not_send_command $BwlfCluster $experiment $Benchmark_length_minutes $Start_Node $Riak_version; 
			fi

		done
	done
done


