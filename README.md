Benchmarking the Scalability and Elasticity of Riak
-----------

Introduction
------------
In the [RELEASE project] (http://www.release-project.eu/) we aim to improve the scalability of Erlang on emergent commodity architectures with 100,000 cores. Such architectures require scalable and available persistent storage on up to 100 hosts. We evaluate the suitability of four popular Erlang DBMSs ([Mnesia] (http://www.erlang.org/doc/man/mnesia.html), [CouchDB] (http://couchdb.apache.org/), [Riak] (http://basho.com/riak/), and [Cassandra] (http://cassandra.apache.org/)) for large-scale architectures. Our theoretical evaluation shows that Dynamo-style NoSQL DBMS like Riak and Cassandra do have a potential to provide scalable storage for large distributed architecture as required by the RELEASE project. Then, we investigate Riak scalability and elasticity in practice by employing Basho Bench on the Kalkyl cluster with 100 nodes. For more information please find the report (`report.pdf`). Here we explain how to customize the scripts to match your specific environment.

Customization
------------
In the cluster each node can be either a trafﬁc generator or a Riak node. A trafﬁc generator node runs one copy of Basho Bench that generates and sends commands to Riak nodes. A Riak node contains a complete and independent copy of the Riak package which is identiﬁed by an IP address and a port number.

Following issues are configurable in the `run.sh` file:

*	The duration of a benchmark in minutes
*	The ratio of traffic generator nodes to Riak nodes
*	Riak Version
*	Number of times that experiment repeats
*	Number of nodes that will go down and come up during elastisity benchmark
	
Following issues are configurable in the `experiment.sh` file:

*	Storage backend for Riak, i.e. Bitcask or eLevelDB 
*	Erlang path for compiling Riak and Basho Bench
*	R statistics language path to generate graph
*	Name and IP address of nodes in the cluster
	
There are two general config files for Basho Bench in the `basho_bench_config` directory, one for HTTP interace and the another for the Protocol Buffers interface. The following issues are configurable in the config files:

*	Number of worker process on each traffic generator node
*	Database commands (e.g. `get`, `insert`, `update`) that are used in the benchmark

How to run the benchmark  
----------------------------------------

	$ git clone git://github.com/amirghaffari/benchmark_riak
	$ cd benchmark_riak
	After customizing the `run.sh` and `experiment.sh` files:
	$ ./run.sh 

