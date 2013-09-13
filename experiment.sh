#!/bin/bash -l
#SBATCH -A p2012172
#SBATCH -p node -N 0 -n 0
#SBATCH -t 00:00:00

# author: Amir Ghaffari
# @RELEASE project (http://www.release-project.eu/)

Use_old_Erlang_version='riak-1.1.1'; # Erlang version R14B04 will be used for Riak version 1.1.1


# specifies a backend for Riak, eleveldb or bitcask
#Riak_backend='eleveldb';
Riak_backend='bitcask';

# specifies an interface to access Riak, HTTP or Protocol Buffers
Interface='http';
#Interface='buffer_protocol';

Number_of_Riak_Nodes=$1;
Number_of_Generator_Nodes=$2;
String_Do_not_send_command=$3;
BwlfCluster=$4; # Specifies whether the cluster is at Heriot-Watt or Uppsala
experiment=$5;
Benchmark_length_minutes=$6; # how long the benchmark takes in minutes
Start_Node=$7; # specifies the start node. I use it when some of the first nodes in beowulf cluster are busy.
Riak_version=$8; # specifies the version of Riak which is used in this benchmark.

let Total_Nodes=$Number_of_Riak_Nodes+$Number_of_Generator_Nodes;
let Generator_Nodes_From=$Number_of_Riak_Nodes+1;
Generator_Nodes_To=$Total_Nodes;
let Ring_size=$Number_of_Riak_Nodes*16;
power_two=1
while [  $power_two -lt $Ring_size ]; do
	let power_two=$power_two*2 
done
Ring_size=$power_two

if [ $String_Do_not_send_command = "empty" ]; then
	String_Do_not_send_command=""
fi

let Benchmark_length_seconds=$Benchmark_length_minutes*60; 
let Report_interval_seconds=$Benchmark_length_seconds/10;
Short_benchmark_time_minutes=1; 

#Elasticity benchmark
# No command is sent to the nodes which are specified in String_Do_not_send_command, because these nodes will go down and come back during the benchmark
i=1
OLDIFS=$IFS
export IFS=";"
for WORD in ${String_Do_not_send_command}; do
		temp=`echo $WORD | bc`;
		int_temp=`printf %0.f $temp `;
        Do_not_send_command[$i]=$int_temp;
        ((i=i+1))
done
let Number_of_Do_not_send_command=$i-1;
export IFS=$OLDIFS

if [ ${Number_of_Do_not_send_command} -gt 0 ] ; then #Elasticity benchmark
	Original_Benchmark_length_seconds=$Benchmark_length_seconds;
	Original_Benchmark_length_minutes=$Benchmark_length_minutes;
	let Benchmark_length_minutes=${Benchmark_length_minutes}*3+4*${Number_of_Do_not_send_command}
	let Benchmark_length_seconds=$Benchmark_length_minutes*60; 
	let Report_interval_seconds=$Report_interval_seconds*3;
fi
#end of Elasticity benchmark

Base_directory=`pwd`;
Riak_Source="${Base_directory}/Riak_Source";
Basho_bench_config_files="${Base_directory}/basho_bench_config";
Number_of_RiakTestTry=10; # the maximum times that a Riak node will be tested for a successful reply

Directory_name=${Riak_version}_${Riak_backend}_${Interface}_${Benchmark_length_minutes}mins_Elasticity_${Number_of_Do_not_send_command}

if $BwlfCluster ; then
	Result_directory="${Base_directory}/results/heriot_watt/${Directory_name}/Riak_${Number_of_Riak_Nodes}_Gens_${Number_of_Generator_Nodes}_Exp_${experiment}";
	if [ $Riak_version = $Use_old_Erlang_version ]; then
		Erlang_path="/home/ag275/erlang/bin";  # Erlang R16B for basho bench
		Old_Erlang_path="/home/ag275/olderlang/bin";  # Erlang R14B04 for riak version 1.1.1
	else
		Erlang_path="/home/ag275/erlang/bin";     # Erlang R16B for riak versions 1.2.* 1.3.* 1.4.*
		Old_Erlang_path="/home/ag275/erlang/bin"; # Erlang R16B for basho bench 
	fi
	R_path="/home/ag275/R/R-3.0.1/bin";
	SNIC_TMP="/scratch"
	Killing_nodes=32; # To kill and clean any previous Erlang VM and Riak nodes that maybe exist. There are 32 nodes at Heriot-Watt's beowulf cluster  
else
	Result_directory="${Base_directory}/results/uppsala/${Directory_name}/Riak_${Number_of_Riak_Nodes}_Gens_${Number_of_Generator_Nodes}_Exp_${experiment}";
	if [ $Riak_version = $Use_old_Erlang_version ]; then
		New_Erlang_path="/bubo/home/h8/ag275/erlang/bin"; # Erlang R16B for basho bench 
		Old_Erlang_path="/bubo/home/h8/ag275/olderlang/bin"; # Erlang R14B04 for riak version 1.1.1
	else
		Erlang_path="/bubo/home/h8/ag275/erlang/bin";    # for riak version 1.1.1
		Old_Erlang_path="/bubo/home/h8/ag275/erlang/bin";# for basho bench 
	fi
	R_path="/bubo/home/h8/ag275/R/bin";
	Killing_nodes=0;
fi

if [ ! -d "$Result_directory" ]; then
	mkdir -p $Result_directory;
else
	cd $Result_directory;
	current_path=`pwd`;
	if [ $current_path = $Result_directory ]; then
		rm -rf *;
	else
		echo "Result directory does not exist"
		exit;
	fi
fi

if [ ! -f "${Riak_Source}/${Riak_version}.tar.gz" ];
then
	cd ${Riak_Source};
	Address_to_download="http://s3.amazonaws.com/downloads.basho.com/riak/${Riak_version:5:7}/${Riak_version:6:10}/${Riak_version}.tar.gz"
	echo "download $Riak_version from: $Address_to_download"
	curl -O $Address_to_download
	if [ ! -f "${Riak_version}.tar.gz" ];
	then
		echo "Riak file does not exist"
		exit;
	fi
fi

cd $Base_directory

# activities are logged in $Output_file_name file
Output_file_name="${Result_directory}/output_Riak_${Number_of_Riak_Nodes}_Gens_${Number_of_Generator_Nodes}_Exp_${experiment}";
# $Bench_config_file is the name  and path of config file for Basho Bench 
Bench_config_file="${Result_directory}/basho_bench_Riak_${Number_of_Riak_Nodes}_Gens_${Number_of_Generator_Nodes}_Exp_${experiment}.config";


# Name and IP addresses of all nodes in the cluster are generated for later use
if $BwlfCluster ; then
# use Heriot-Watt University's beowulf cluster 
	let To_Node=$Start_Node+$Total_Nodes-1;
	Node_Counter=0;
	for index in `seq $Start_Node $To_Node`; do 
			let Node_Counter=$Node_Counter+1;
			if [ "$index" -lt 10 ]
			then
				Hostnames[$Node_Counter]="bwlf0${index}.macs.hw.ac.uk";
				IPaddresses[$Node_Counter]=`ssh -q ${Hostnames[$Node_Counter]} "hostname -i;"`;
			else
				Hostnames[$Node_Counter]="bwlf${index}.macs.hw.ac.uk";
				IPaddresses[$Node_Counter]=`ssh -q ${Hostnames[$Node_Counter]} "hostname -i;"`
				echo "more than 10 ($index) ${Hostnames[$Node_Counter]}  ${IPaddresses[$Node_Counter]} " 
			fi
		# records the network status before the benchmark
		Result_netstat=`ssh ${Hostnames[$Node_Counter]} "netstat -s"`;
		before_sent_packets[$Node_Counter]=$(echo "$Result_netstat" | grep 'segments send out'| awk  '{print $1}'| head -1)
		before_received_packets[$Node_Counter]=$(echo "$Result_netstat" | grep 'segments received'| awk  '{print $1}'| head -1)
		before_retransmission_packets[$Node_Counter]=$(echo "$Result_netstat" | grep 'retransmited'| awk  '{print $1}')
	done

else
	# use Uppsala University's kalkyl cluster
	for index in `seq 1 $Total_Nodes`; do 
		let zero_index=$index-1;
		tempip=`srun -r $zero_index  -N 1 -n 1 bash -c "hostname -i"`; 
		temphostname=`srun -r  $zero_index -N 1 -n 1 bash -c hostname`;

		# records the network status before the benchmark
		Result_netstat=`srun -r $zero_index  -N 1 -n 1 bash -c "netstat -s"`;
		before_sent_packets[$index]=$(echo "$Result_netstat" | grep 'segments send out'| awk  '{print $1}'| head -1)
		before_received_packets[$index]=$(echo "$Result_netstat" | grep 'segments received'| awk  '{print $1}'| head -1)
		before_retransmission_packets[$index]=$(echo "$Result_netstat" | grep 'retransmited'| awk  '{print $1}')

		IPaddresses[$index]=$tempip;
		Hostnames[$index]=$temphostname;
	done

fi

cd $Base_directory
# sleep definitions
source constant.sh

echo "start at time :">$Output_file_name;
date +'%T'>>$Output_file_name;
echo "Riak version is: ${Riak_version} and backend is ${Riak_backend} Interface is ${Interface} Ring_size=$Ring_size and Except Riak nodes are: $String_Do_not_send_command">>$Output_file_name;
echo "====================">>$Output_file_name;

PATH=$Erlang_path:$R_path:$PATH;
export PATH;
echo 'Erlang path is:'>>$Output_file_name;
which erl >>$Output_file_name;

for index in `seq 1 $Total_Nodes`; do 
	echo "IP is ${IPaddresses[$index]} and name is ${Hostnames[$index]} for index $index">>$Output_file_name;
done

# Put all nodes' IP address in a proper format in $String_format_addresses to be used later in the Basho Bench's config file
if [ $Interface = 'http' ]; then
	Double_qoutes="\"";
	Double_qoutes_comma=",\"";
	String_format_addresses="";

	for index in `seq 1 $Number_of_Riak_Nodes`; do
		##############
		Found=false;
		for loop_counter in `seq 1 $Number_of_Do_not_send_command`;
		do
			if [ ${Do_not_send_command[$loop_counter]} -eq $index ] ; then
				echo "Riak node $index is exception from sending commands">>$Output_file_name;
				Found=true;
			fi
		done
		if $Found ; then
			continue;
		fi
		#############	
		if [ $index -eq 1 ]
		then
			String_format_addresses=${String_format_addresses}${Double_qoutes}${IPaddresses[$index]}${Double_qoutes}
		else
			String_format_addresses=${String_format_addresses}${Double_qoutes_comma}${IPaddresses[$index]}${Double_qoutes}
		fi
	done
else
	Double_qoutes_first="{\"";
	Double_qoutes_end="\",[8087]}";
	Comma=",";
	String_format_addresses="";
	for index in `seq 1 $Number_of_Riak_Nodes`; do

		##############
		Found=false;
		for loop_counter in `seq 1 $Number_of_Do_not_send_command`;
		do
			if [ ${Do_not_send_command[$loop_counter]} -eq $index ] ; then
				echo "Riak node $index is exception from sending commands">>$Output_file_name;
				Found=true;
			fi
		done
		if $Found ; then
			continue;
		fi
		#############	
		
		if [ $index -eq 1 ]
		then
			String_format_addresses=${String_format_addresses}${Double_qoutes_first}${IPaddresses[$index]}${Double_qoutes_end}
		else
			String_format_addresses=${String_format_addresses}${Comma}${Double_qoutes_first}${IPaddresses[$index]}${Double_qoutes_end}
		fi
	done
fi	

echo "Number of Riak nodes is $Number_of_Riak_Nodes">>$Output_file_name;
echo "Number of generator nodes are $Number_of_Generator_Nodes from $Generator_Nodes_From to $Generator_Nodes_To">>$Output_file_name;
echo "IP addresses for Riak nodes are: $String_format_addresses">>$Output_file_name;

if [ ! -d "$Basho_bench_config_files" ]; then
	echo "Directory $Basho_bench_config_files doesn't exist">>$Output_file_name;
	echo "Directory $Basho_bench_config_files doesn't exist";
	exit;
fi

if [ $Interface = 'http' ]; then
	Original_Config_File="${Basho_bench_config_files}/http_original_basho_bench.config";
else
	Original_Config_File="${Basho_bench_config_files}/bp_original_basho_bench.config";
fi

# Before running the main benchmar, a short time benchmarking will be run to make the cluster stable and ready for the main benchmark
# Short_config_file is a config file for the short benchmark
Short_config_file="${Bench_config_file}_short"
sed "s/\"127.0.0.1\"/$String_format_addresses/g" $Original_Config_File>$Bench_config_file;
sed "s/minutes/$Short_benchmark_time_minutes/g" $Bench_config_file>${Short_config_file};
sed -i "s/max/{rate, 15}/g" ${Short_config_file};
sed -i "s/report_interval_seconds/$Report_interval_seconds/g" ${Short_config_file};
sed -i "s/minutes/$Benchmark_length_minutes/g" $Bench_config_file;
sed -i "s/report_interval_seconds/$Report_interval_seconds/g" $Bench_config_file;

# kill and clean any previous Erlang VM and Riak nodes that maybe exist
for index in `seq 1 $Killing_nodes`; do 
	ssh -q ${IPaddresses[$index]} "
	echo '========================= killing (index=$index) ==================';
	pwd;
	hostname -i;
	hostname;
	date +'%T';
	echo 'befor kill=====';
	top -b -n 1 | grep beam.smp;
	pkill beam.smp;
	pkill beam;
	pkill epmd;
	kill $(pgrep beam.smp);
	echo 'after kill=====';
	top -b -n 1 | grep beam.smp;
	echo 'time:';
	date +'%T';
	cd $SNIC_TMP;
	rm -rf ${Riak_version};
	ls ${Riak_version};
	pkill -u ag275; # kill epmd in case it's still alive
	";
done

echo "==========================================After killing and cleaning VMs and previous Riak nodes">>$Output_file_name;
date +'%T'>>$Output_file_name;

############### install Riak

First_Node=riak@${IPaddresses[1]}
Log_Riak_Installation="${Result_directory}/Log_Riak_Installation"
mkdir -p $Log_Riak_Installation;

for index in `seq 1 $Number_of_Riak_Nodes`; do 
	(ssh -q ${IPaddresses[$index]} "
	date +'%T';
	if [ $Riak_version = $Use_old_Erlang_version ]; then
		PATH=$Old_Erlang_path:$R_path:$PATH;
		export PATH;
	else
		PATH=$Erlang_path:$R_path:$PATH;
		export PATH;
	fi
	echo 'Erlang path is:'
	which erl 
	cd $SNIC_TMP;
	rm -rf ${Riak_version};
	cp ${Riak_Source}/${Riak_version}.tar.gz .
	tar zxvf ${Riak_version}.tar.gz;
	cd ${Riak_version};
	echo 'installing Riak on hostname and path at time:';
	pwd;
	hostname -i;
	date +'%T';

	make rel;

	cp rel/riak/etc/app.config rel/riak/etc/old_app.config;
	cp rel/riak/etc/vm.args rel/riak/etc/old_vm.args;
	sed -i \"s/127.0.0.1/${IPaddresses[$index]}/g\" rel/riak/etc/app.config ;
	if [ $Riak_backend = 'eleveldb' ]; then
		echp 'Here change to eleveldb ....'
		sed -i \"s/riak_kv_bitcask_backend/riak_kv_eleveldb_backend/g\" rel/riak/etc/app.config ;
	fi
	sed -i \"/ring_state_dir/a{ring_creation_size, $Ring_size},\" rel/riak/etc/app.config ; 
	sed -i \"s/127.0.0.1/${IPaddresses[$index]}/g\" rel/riak/etc/vm.args;
	echo \"debug: node ${IPaddresses[$index]} is starting\";
	rel/riak/bin/riak start;
	rel/riak/bin/riak ping;
	
	echo \"debug: ${IPaddresses[$index]} wants to connect $First_Node   \";
	
	if [ $Riak_version = $Use_old_Erlang_version ]; then
		if [ riak@${IPaddresses[$index]} = $First_Node ]; then
			echo 'This is the first node in the cluster'
		else
			rel/riak/bin/riak-admin join $First_Node;
		fi
	else
		if [ riak@${IPaddresses[$index]} = $First_Node ]; then
			echo 'This is the first node in the cluster'
		else
			rel/riak/bin/riak-admin cluster join $First_Node;
			rel/riak/bin/riak-admin cluster plan;
			rel/riak/bin/riak-admin cluster commit;
		fi
	fi	

	rel/riak/bin/riak-admin ringready;

	for count_try in {1..$Number_of_RiakTestTry}
	do
		Temp_result=\$(rel/riak/bin/riak ping);
		Find_this=\"pong\"
		if echo \"\$Temp_result\" | grep -q \"\$Find_this\"; then
			echo \" Successful reply to ping for \$count_try times\"
			break;
		else
			echo \" Faild for \$count_try times: (\$Temp_result)\"
			sleep 1
		fi
		let Half_of_try=$Number_of_RiakTestTry/2;
		if [ \$count_try -eq \$Half_of_try ]
		then
				echo \" Stop and Start the node to solve the problem\"
				rel/riak/bin/riak stop;
				rel/riak/bin/riak start;
				rel/riak/bin/riak reboot
				rel/riak/bin/riak ping;
				rel/riak/bin/riak-admin ringready;
		fi
	done


	zip -r RiakNode_${index}_Exp_${experiment}.zip rel/riak/etc/app.config rel/riak/etc/vm.args rel/riak/etc/old_app.config rel/riak/etc/old_vm.args;
	mv     RiakNode_${index}_Exp_${experiment}.zip ${Log_Riak_Installation};
	echo 'debug: installing riak on node ${IPaddresses[$index]} is finished at time:';
	date +'%T';
	">${Log_Riak_Installation}/RiakNode_${index}_Exp_${experiment}
	)&

	if [ $index -eq 1 ]
		then
		  sleep $Sleep_first_Riak_node; # for the first Riak node
		else
			sleep $Sleep_other_Riak_node; # for other Riak nodes
	fi

done

echo "debug: sleep ($Sleep_to_Install_Riak_Nodes seconds) to install all Riak nodes ">>$Output_file_name;
sleep $Sleep_to_Install_Riak_Nodes; 
echo "debug: Here all Riak nodes are installed">>$Output_file_name;

let Sleep_to_Get_Stable=$Number_of_Riak_Nodes*$Sleep_to_Get_Stable_per_node;
echo "debug: sleep ($Sleep_to_Get_Stable seconds) to get stable Riak cluster">>$Output_file_name;
sleep $Sleep_to_Get_Stable;

echo "debug: Connect again to check Riak nodes in the cluster">>$Output_file_name;
for index in 1 $Number_of_Riak_Nodes 
do 
	ssh -q ${IPaddresses[$index]} "
	echo ===================================
	if [ $Riak_version = $Use_old_Erlang_version ]; then
		PATH=$Old_Erlang_path:$R_path:$PATH;
		export PATH;
	else
		PATH=$Erlang_path:$R_path:$PATH;
		export PATH;
	fi
	cd $SNIC_TMP;
	cd ${Riak_version};
	echo 'debug: current path is:';
	pwd;
	hostname -i;
	rel/riak/bin/riak-admin test;
	rel/riak/bin/riak-admin ringready;
	#rel/riak/bin/riak-admin status | grep ring_members
	">>$Output_file_name;
done

echo "End of second round check Riak nodes==============================">>$Output_file_name;

let Sleep_after_short_bench=$Number_of_Riak_Nodes*$Sleep_after_short_bench_per_node;


####################### install Basho Bench
Log_BashoBench_Installation="${Result_directory}/Log_BashoBench_Installation"
mkdir -p $Log_BashoBench_Installation;
time_start=`date +%s`
for index in `seq $Generator_Nodes_From $Generator_Nodes_To`; do 
echo "debug:  we are in loop for running benchmark by index $index on ${IPaddresses[$index]}">>$Output_file_name;
(ssh -q ${IPaddresses[$index]} "
PATH=$New_Erlang_path:$R_path:$PATH;
export PATH;
cd $SNIC_TMP;
echo 'Erlang path is:'
which erl 
	
echo \"debug: copy benchmark application from: ${Base_directory}/basho_bench \";
cp -r ${Base_directory}/basho_bench .

cd basho_bench;
echo 'debug: here benchmark application is running on host and path:'
hostname -i;
pwd;

echo \"debug: here benchmark application is running on ${IPaddresses[$index]} with index $index \";
echo 'debug: current time in stage 1 is ';
date +'%T';
make;
cp ${Bench_config_file} .;
cp ${Short_config_file} .;

echo 'debug: before running the short benchmark at time:';
date +'%T';
echo \"debug: short config file is ${Short_config_file}\";
./basho_bench ${Short_config_file};

echo \"debug: Sleep $Sleep_after_short_bench seconds after short benchmark\";
date +'%T';
sleep $Sleep_after_short_bench;
echo \"debug: Wake up to run the main benchmark\";
date +'%T';

echo 'debug: before running the benchmark at time:';
date +'%T';
echo \"debug: config file is $Bench_config_file\";
./basho_bench $Bench_config_file;
echo 'debug: after run and before makinging the graph, current time in stage 2 is ';
date +'%T';
cp ${Base_directory}/graphs/* priv/;
make results;
echo 'let see png files:';
find . -name *.png;
echo 'debug: before zipping and moving the result';
zip -r Riak_${Number_of_Riak_Nodes}_Gens_${Number_of_Generator_Nodes}_Exp_${experiment}_index_$index.zip tests/current/*;
mv     Riak_${Number_of_Riak_Nodes}_Gens_${Number_of_Generator_Nodes}_Exp_${experiment}_index_$index.zip ${Result_directory};

echo 'debug: after zipping and moving the result ';
echo 'debug: current time in stage 3 is ';
date +'%T';
">${Log_BashoBench_Installation}/BashoBench_${index}_Exp_${experiment}
)&
sleep $Sleep_to_Delay_Copy_Bash_Bench;
done

Time_BashoBench_Takes_To_Installed=180; # 3 minutes takes to copy and install each generator node
let Sleep_time_to_get_finish_benchmark=$Benchmark_length_seconds+$Sleep_after_short_bench+$Short_benchmark_time_minutes*60+$Time_BashoBench_Takes_To_Installed;

echo "debug: Total sleeping time for benchmark:  $Sleep_time_to_get_finish_benchmark seconds">>$Output_file_name;

if [ ${Number_of_Do_not_send_command} -eq 0 ] ; then

		let first_half_sleep=$Sleep_after_short_bench+$Short_benchmark_time_minutes*60+$Benchmark_length_seconds/2+$Time_BashoBench_Takes_To_Installed/3;

		echo "debug: First sleeping for benchmark result $first_half_sleep seconds">>$Output_file_name;
		echo "debug: Time is:">>$Output_file_name;
		date +'%T'>>$Output_file_name;
		sleep $first_half_sleep;

		############################################### Recording the CPU and Memory usage

		Riak_sum_cpu_usage=0;
		Riak_sum_memory_usage=0;
		for index in `seq 1 $Number_of_Riak_Nodes`; do 

			echo "debug: Running top on ${IPaddresses[$index]} ========================================">>$Output_file_name;
			Riak_cpu_usage=`ssh ${IPaddresses[$index]} " top -b -n 1 " | grep 'beam.smp' | awk '{print $9}' | awk '{sum+=$1} END {print sum}'`
			Total_cpu_usage=`ssh ${IPaddresses[$index]} " top -b -n 1 " | awk '{print $9}' | awk '{sum+=$1} END {print sum}'`
			
			echo "debug: Total cpu usage on ${IPaddresses[$index]} = $Total_cpu_usage ">>$Output_file_name;
			echo "debug: Riak  cpu usage on ${IPaddresses[$index]} = $Riak_cpu_usage  ">>$Output_file_name;
			Riak_sum_cpu_usage=$(awk "BEGIN {print $Riak_sum_cpu_usage+$Total_cpu_usage; exit}")

			Riak_memory_usage=`ssh ${IPaddresses[$index]} " top -b -n 1 " | grep 'beam.smp' | awk '{print $10}' | awk '{sum+=$1} END {print sum}'`
			Total_memory_usage=`ssh ${IPaddresses[$index]} " top -b -n 1 " | awk '{print $10}' | awk '{sum+=$1} END {print sum}'`

			echo "debug: Total memory usage on ${IPaddresses[$index]} = $Total_memory_usage ">>$Output_file_name;
			echo "debug: Riak  memory usage on ${IPaddresses[$index]} = $Riak_memory_usage  ">>$Output_file_name;

			Riak_sum_memory_usage=$(awk "BEGIN {print $Riak_sum_memory_usage+$Total_memory_usage; exit}")
			echo "End of ${IPaddresses[$index]} ***********************************************">>$Output_file_name;
		done
		Riak_sum_cpu_usage=$(awk "BEGIN {print $Riak_sum_cpu_usage/$Number_of_Riak_Nodes; exit}")
		Riak_sum_memory_usage=$(awk "BEGIN {print $Riak_sum_memory_usage/$Number_of_Riak_Nodes; exit}")

		echo "=====================End of recording the CPU and Memory usage for Riak nodes">>$Output_file_name;


		Bench_sum_cpu_usage=0;
		Bench_sum_memory_usage=0;
		for index in `seq $Generator_Nodes_From $Generator_Nodes_To`; do 
		
			echo "debug: Running top on ${IPaddresses[$index]} ========================================">>$Output_file_name;
			Bench_cpu_usage=`ssh ${IPaddresses[$index]} " top -b -n 1 " | grep 'beam.smp' | awk '{print $9}' | awk '{sum+=$1} END {print sum}'`
			Total_cpu_usage=`ssh ${IPaddresses[$index]} " top -b -n 1 " | awk '{print $9}' | awk '{sum+=$1} END {print sum}'`
			
			echo "debug: Total cpu usage on ${IPaddresses[$index]} = $Total_cpu_usage ">>$Output_file_name;
			echo "debug: Basho Bench  cpu usage on ${IPaddresses[$index]} = $Bench_cpu_usage ">>$Output_file_name;
			Bench_sum_cpu_usage=$(awk "BEGIN {print $Bench_sum_cpu_usage+$Total_cpu_usage; exit}")

			Bench_memory_usage=`ssh ${IPaddresses[$index]} " top -b -n 1 " | grep 'beam.smp' | awk '{print $10}' | awk '{sum+=$1} END {print sum}'`
			Total_memory_usage=`ssh ${IPaddresses[$index]} " top -b -n 1 " | awk '{print $10}' | awk '{sum+=$1} END {print sum}'`

			echo "debug: Total memory usage on ${IPaddresses[$index]} = $Total_memory_usage ">>$Output_file_name;
			echo "debug: Basho Bench memory usage on ${IPaddresses[$index]} = $Bench_memory_usage  ">>$Output_file_name;

			Bench_sum_memory_usage=$(awk "BEGIN {print $Bench_sum_memory_usage+$Total_memory_usage; exit}")
			echo "End of ${IPaddresses[$index]} ***********************************************">>$Output_file_name;

		done
		Bench_sum_cpu_usage=$(awk "BEGIN {print $Bench_sum_cpu_usage/$Number_of_Generator_Nodes; exit}")
		Bench_sum_memory_usage=$(awk "BEGIN {print $Bench_sum_memory_usage/$Number_of_Generator_Nodes; exit}")

		echo "debug: End of recording the CPU and Memory usage for Basho Bench nodes">>$Output_file_name;


		############################################### end of measuring CPU and Memory usage

		############################################### start of measuring Disk usage

		number_of_read=0;
		number_of_write=0;
		io_wait=0;
		echo "debug: before disk Time is:">>$Output_file_name;
		date +'%T'>>$Output_file_name;

		for index in `seq 1 $Total_Nodes`; do 
			disk_query[$index]=`ssh ${IPaddresses[$index]} "iostat -dx 4 2  sda | grep 'sda' | tail -n 1"`;
		done

		echo "debug: after disk Time is:">>$Output_file_name;
		date +'%T'>>$Output_file_name;

		total_disk_util_riak=0;
		total_number_of_read_riak=0;
		total_number_of_write_riak=0;
		total_io_wait_riak=0;
		####
		total_disk_util_bench=0;
		total_number_of_read_bench=0;
		total_number_of_write_bench=0;
		total_io_wait_bench=0;
		####
		for index in `seq 1 $Total_Nodes`; do 
			echo "debug: disk result is ${disk_query[$index]}">>$Output_file_name;
			temp=${disk_query[$index]};
			number_of_read=$(echo "$temp" | awk '{print $4}');
			echo "debug: disk result is number_of_read : $number_of_read">>$Output_file_name;
			number_of_write=$(echo "$temp" | awk '{print $5}');
			echo "debug: disk result is number_of_write : $number_of_write">>$Output_file_name;
			io_wait=$(echo "$temp" | awk '{print $10}'); #milliseconds
			echo "debug: disk result is io_wait : $io_wait">>$Output_file_name;
			disk_util=$(echo "$temp" | awk '{print $12}'); #percentage
			echo "debug: disk result is disk_util : $disk_util">>$Output_file_name;
			echo "===============">>$Output_file_name;
			if [ $index -le $Number_of_Riak_Nodes ]
			then
					total_number_of_read_riak=`echo $total_number_of_read_riak + $number_of_read | bc`;
					total_number_of_write_riak=`echo $total_number_of_write_riak + $number_of_write | bc`;
					total_io_wait_riak=`echo $total_io_wait_riak + $io_wait | bc`;
					total_disk_util_riak=`echo $total_disk_util_riak + $disk_util | bc`;
					echo "debug: riak disk result is total_number_of_read_riak : $total_number_of_read_riak">>$Output_file_name;
					echo "debug: riak disk result is total_number_of_write_riak : $total_number_of_write_riak">>$Output_file_name;
					echo "debug: riak disk result is total_io_wait_riak : $total_io_wait_riak">>$Output_file_name;
					echo "debug: riak disk result is total_disk_util_riak : $total_disk_util_riak">>$Output_file_name;
					echo "=========================================================">>$Output_file_name;
				else
					total_number_of_read_bench=`echo $total_number_of_read_bench + $number_of_read | bc`;
					total_number_of_write_bench=`echo $total_number_of_write_bench + $number_of_write | bc`;
					total_io_wait_bench=`echo $total_io_wait_bench + $io_wait | bc`;
					total_disk_util_bench=`echo $total_disk_util_bench + $disk_util | bc`;
					echo "debug: bench disk result is total_number_of_read_bench : $total_number_of_read_bench">>$Output_file_name;
					echo "debug: bench disk result is total_number_of_write_bench : $total_number_of_write_bench">>$Output_file_name;
					echo "debug: bench disk result is total_io_wait_bench : $total_io_wait_bench">>$Output_file_name;
					echo "debug: bench disk result is total_disk_util_bench : $total_disk_util_bench">>$Output_file_name;
					echo "=========================================================">>$Output_file_name;
				fi
		done

		total_number_of_read_riak=`echo $total_number_of_read_riak / $Number_of_Riak_Nodes | bc`;
		total_number_of_write_riak=`echo $total_number_of_write_riak / $Number_of_Riak_Nodes | bc`;
		total_io_wait_riak=`echo $total_io_wait_riak / $Number_of_Riak_Nodes | bc`;
		total_disk_util_riak=`echo $total_disk_util_riak / $Number_of_Riak_Nodes | bc`;
		#
		total_number_of_read_bench=`echo $total_number_of_read_bench / $Number_of_Generator_Nodes | bc`;
		total_number_of_write_bench=`echo $total_number_of_write_bench / $Number_of_Generator_Nodes | bc`;
		total_io_wait_bench=`echo $total_io_wait_bench / $Number_of_Generator_Nodes | bc`;
		total_disk_util_bench=`echo $total_disk_util_bench / $Number_of_Generator_Nodes | bc`;

		#######################################
		let second_half_sleep=$Sleep_time_to_get_finish_benchmark-$first_half_sleep;
		echo "debug: Second part of sleeping for benchmark result $second_half_sleep seconds">>$Output_file_name;
		echo "debug: Time is:">>$Output_file_name;
		date +'%T'>>$Output_file_name;
		sleep $second_half_sleep;

		sum_sent_packets=0;
		sum_received_packets=0;
		sum_retransmission_packets=0;

		sum_sent_packets_riak=0;
		sum_received_packets_riak=0;
		sum_retransmission_packets_riak=0;

		sum_sent_packets_banch=0;
		sum_received_packets_bench=0;
		sum_retransmission_packets_bench=0;

		for index in `seq 1 $Total_Nodes`; do 
		let zero_index=$index-1;
		#########
		if $BwlfCluster ; then
			Result_netstat=`ssh ${IPaddresses[$index]} "netstat -s"`;
		else
			Result_netstat=`srun -r $zero_index  -N 1 -n 1 bash -c "netstat -s"`;
		fi
		#########
		after_sent_packets=$(echo "$Result_netstat" | grep 'segments send out'| awk  '{print $1}'| head -1)
		after_received_packets=$(echo "$Result_netstat" | grep 'segments received'| awk  '{print $1}'| head -1)
		after_retransmission_packets=$(echo "$Result_netstat" | grep 'retransmited'| awk  '{print $1}')
		#########
		temp_after_sent_packets=`echo $after_sent_packets | bc`
		temp_after_received_packets=`echo $after_received_packets | bc`
		temp_after_retransmission_packets=`echo $after_retransmission_packets | bc`
		#########
		temp_before_sent_packets=`echo ${before_sent_packets[$index]} | bc`
		temp_before_received_packets=`echo ${before_received_packets[$index]} | bc`
		temp_before_retransmission_packets=`echo ${before_retransmission_packets[$index]} | bc`
		##############
		echo "sent before was $temp_before_sent_packets and after is $temp_after_sent_packets">>$Output_file_name;
		echo "receive before was $temp_before_received_packets and after is $temp_after_received_packets">>$Output_file_name;
		echo "retransmission before was $temp_before_retransmission_packets and after is $temp_after_retransmission_packets">>$Output_file_name;
		echo "===========================================================">>$Output_file_name;
		#########
		let sum_sent_packets=sum_sent_packets+temp_after_sent_packets-temp_before_sent_packets;
		let sum_received_packets=sum_received_packets+temp_after_received_packets-temp_before_received_packets;
		let sum_retransmission_packets=sum_retransmission_packets+temp_after_retransmission_packets-temp_before_retransmission_packets;
		#########
			if [ $index -le $Number_of_Riak_Nodes ]
			then
				let sum_sent_packets_riak=sum_sent_packets_riak+temp_after_sent_packets-temp_before_sent_packets;
				let sum_received_packets_riak=sum_received_packets_riak+temp_after_received_packets-temp_before_received_packets;
				let sum_retransmission_packets_riak=sum_retransmission_packets_riak+temp_after_retransmission_packets-temp_before_retransmission_packets;		
			else
				let sum_sent_packets_banch=sum_sent_packets_banch+temp_after_sent_packets-temp_before_sent_packets;
				let sum_received_packets_bench=sum_received_packets_bench+temp_after_received_packets-temp_before_received_packets;
				let sum_retransmission_packets_bench=sum_retransmission_packets_bench+temp_after_retransmission_packets-temp_before_retransmission_packets;	
			fi

		done
		echo "=========== Total network trrafic ======================================================">>$Output_file_name;
		echo "sent_packets= $sum_sent_packets">>$Output_file_name;
		echo "received_packets= $sum_received_packets">>$Output_file_name;
		echo "retransmission_packets= $sum_retransmission_packets">>$Output_file_name;
		############
		echo "======= Riak network packets ================">>$Output_file_name;
		echo "sent_packets_riak= $sum_sent_packets_riak">>$Output_file_name;
		echo "received_packets_riak= $sum_received_packets_riak">>$Output_file_name;
		echo "retransmission_packets_riak= $sum_retransmission_packets_riak">>$Output_file_name;
		######
		echo "======= Bench APP network packets ==================">>$Output_file_name;
		echo "sent_packets_bench= $sum_sent_packets_banch">>$Output_file_name;
		echo "received_packets_bench= $sum_received_packets_bench">>$Output_file_name;
		echo "retransmission_packets_bench= $sum_retransmission_packets_bench">>$Output_file_name;
		############
		echo "======= CPU and Memory usage for Riak =====================">>$Output_file_name;
		echo "average_cpu_usage_for_Riak_nodes_percentage: $Riak_sum_cpu_usage">>$Output_file_name;
		echo "average_memory_usage_for_Riak_nodes_percentage: $Riak_sum_memory_usage">>$Output_file_name;
		################
		echo "======= CPU and Memory usage for Bench App ====================">>$Output_file_name;
		echo "average_cpu_usage_for_Bench_nodes_percentage: $Bench_sum_cpu_usage">>$Output_file_name;
		echo "average_memory_usage_for_Bench_nodes_percentage: $Bench_sum_memory_usage">>$Output_file_name;
		###################
		echo "======= Disk usage of Riak nodes ========================">>$Output_file_name;
		echo "debug: (Riak) The number of read requests that were issued to the device per second: $total_number_of_read_riak">>$Output_file_name;
		echo "debug: (Riak) The number of write requests that were issued to the device per second: $total_number_of_write_riak">>$Output_file_name;
		echo "debug: (Riak) The average time (in milliseconds) for I/O requests issued to the device to be served: $total_io_wait_riak">>$Output_file_name;
		echo "debug: (Riak) The number depicts the percentage of time that the device spent in servicing requests: $total_disk_util_riak">>$Output_file_name;
		echo "percentage_of_time_device_spent_servicing_Riak: $total_disk_util_riak">>$Output_file_name;
		echo "======= Disk usage of Bench nodes ========================">>$Output_file_name;
		echo "debug: (Bench) The number of read requests that were issued to the device per second: $total_number_of_read_bench">>$Output_file_name;
		echo "debug: (Bench) The number of write requests that were issued to the device per second: $total_number_of_write_bench">>$Output_file_name;
		echo "debug: (Bench) The average time (in milliseconds) for I/O requests issued to the device to be served: $total_io_wait_bench">>$Output_file_name;
		echo "debug: (Bench) The number depicts the percentage of time that the device spent in servicing requests: $total_disk_util_bench">>$Output_file_name;
		echo "percentage_of_time_device_spent_servicing_Bench: $total_disk_util_bench">>$Output_file_name;
else # Elasticity
		echo "Elasticity started">>$Output_file_name;
		let first_sleep_Elastisity=$Sleep_to_Delay_Copy_Bash_Bench*$Number_of_Generator_Nodes+$Sleep_after_short_bench+$Short_benchmark_time_minutes*60+$Time_BashoBench_Takes_To_Installed/3+$Original_Benchmark_length_seconds;
		echo " Sleeping $first_sleep_Elastisity seconds at time:">>$Output_file_name;
		date +'%T'>>$Output_file_name;
		sleep $first_sleep_Elastisity;
		
		echo "Riak nodes before stop =============================">>$Output_file_name;
		ssh -q ${IPaddresses[1]} "
		PATH=$Erlang_path:$R_path:$PATH;
		export PATH;
		cd $SNIC_TMP;cd ${Riak_version};echo 'current path is:';
		pwd;hostname -i;rel/riak/bin/riak-admin ringready;
		rel/riak/bin/riak-admin test;
		">>$Output_file_name;
		echo " =============================">>$Output_file_name;

		echo " Stoping the Riak nodes at time:">>$Output_file_name;
		date +'%T'>>$Output_file_name;
		for i in "${Do_not_send_command[@]}"
		do
			echo "inside loop to stop ${i}th node with ip address ${IPaddresses[$i]}">>$Output_file_name;
			ssh -q ${IPaddresses[$i]} "
			PATH=$Erlang_path:$R_path:$PATH;
			export PATH;
			cd $SNIC_TMP;
			cd ${Riak_version};
			echo 'current path is:';pwd; echo 'hostname is:'; hostname -i;
			rel/riak/bin/riak stop;
			pkill beam.smp;
			pkill epmd;
			kill $(pgrep beam.smp);">>$Output_file_name;
			sleep 120; #2 minutes
		done

		echo "Riak nodes after stop =============================">>$Output_file_name;
		ssh -q ${IPaddresses[1]} "
		PATH=$Erlang_path:$R_path:$PATH;
		export PATH;
		cd $SNIC_TMP;cd ${Riak_version};echo 'current path is:';
		pwd;hostname -i;rel/riak/bin/riak-admin ringready;
		rel/riak/bin/riak-admin test;
		">>$Output_file_name;
		echo " =============================">>$Output_file_name;
		
		echo " Sleeping $Original_Benchmark_length_seconds seconds at time:">>$Output_file_name;
		date +'%T'>>$Output_file_name;
		sleep $Original_Benchmark_length_seconds;
		echo " Starting the Riak nodes at time:">>$Output_file_name;
		date +'%T'>>$Output_file_name;
		for i in "${Do_not_send_command[@]}"
		do
			echo "inside loop to start ${i}th node with ip address ${IPaddresses[$i]}">>$Output_file_name;
			ssh -q ${IPaddresses[$i]} "
			PATH=$Erlang_path:$R_path:$PATH;
			export PATH;
			cd $SNIC_TMP;
			cd ${Riak_version};
			echo 'current path is:';pwd; echo 'hostname is:'; hostname -i;
			rel/riak/bin/riak start;
			rel/riak/bin/riak ping;
			">>$Output_file_name;
			sleep 120; #2 minutes
		done

		echo " Riak nodes after start again =============================">>$Output_file_name;
		ssh -q ${IPaddresses[1]} "
		PATH=$Erlang_path:$R_path:$PATH;
		export PATH;
		cd $SNIC_TMP;cd ${Riak_version};echo 'current path is:';
		pwd;hostname -i;rel/riak/bin/riak-admin ringready;
		rel/riak/bin/riak-admin test;
		">>$Output_file_name;
		echo " =============================">>$Output_file_name;

		echo " Sleeping $Original_Benchmark_length_seconds seconds at time:">>$Output_file_name;
		date +'%T'>>$Output_file_name;
		sleep $Original_Benchmark_length_seconds;
		sleep $Sleep_to_get_finish_Elastisity;
		echo "End of Elasticity">>$Output_file_name;
fi

cd $Log_Riak_Installation
zip -mr Log_Riak_Installation.zip * 
cd $Log_BashoBench_Installation
zip -mr Log_BashoBench_Installation.zip * 
cd $Result_directory;
zip -mr All.zip *.zip
mkdir all;
cp All.zip all
cd $Base_directory;
rm csv_tool.class
javac csv_tool.java
java csv_tool "${Result_directory}/all/aggregated" "$Result_directory/all";
cd "${Result_directory}/all"
rm -fr All

if [ -f "$Result_directory/all/aggregated/All.zip" ];
then
   rm All.zip
else
  mv All.zip $Result_directory/all/aggregated/   # There is just one file, so keep it
fi

cd "$Result_directory/all/aggregated"
unzip "$Result_directory/all/aggregated/All.zip"
rm All.zip
PATH=$Erlang_path:$R_path:$PATH;
export PATH;
cd $Base_directory;
graphs/summary.r -i "$Result_directory/all/aggregated"

echo "========================= Clean up all Riak nodes";
for index in `seq 1 $Killing_nodes`; do 
	ssh -q ${IPaddresses[$index]} "
	pkill beam.smp;
	pkill beam;
	pkill epmd;
	kill $(pgrep beam.smp);
	cd $SNIC_TMP;
	rm -rf ${Riak_version};
	pkill -u ag275; # kill epmd in case it's still alive
	echo '===========================================';
	";
done
echo "debug: time is: ">>$Output_file_name;
date +'%T'>>$Output_file_name;
time_exec=`expr $(( $time_end - $time_start ))`
echo "debug: time passed over all benchmarks is $time_exec seconds">>$Output_file_name;
echo "debug: End of benchmark=================">>$Output_file_name;




