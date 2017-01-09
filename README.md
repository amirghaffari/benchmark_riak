Benchmarking the Scalability and Elasticity of the Riak NoSQL DBMS
-----------

Introduction
------------
The [RELEASE project] (http://www.release-project.eu/) aims to improve the scalability of [the Erlang programming language] (https://www.erlang.org/). Scalable applications require scalable and available persistent storage to save and retrieve their business data. I evaluate the suitability of four popular NoSQL DBMSs ([Mnesia] (http://www.erlang.org/doc/man/mnesia.html), [CouchDB] (http://couchdb.apache.org/), [Riak] (http://basho.com/riak/), and [Cassandra] (http://cassandra.apache.org/)) for large-scale Erlang applications. I investigate the scalability and elasticity of the Riak NoSQL DBMS by employing the [Basho Bench] (http://docs.basho.com/riak/latest/ops/building/benchmarking/) on the [Kalkyl cluster] (http://www.uppmax.uu.se/resources/systems/) up to 100 nodes. More details about the benchmark are available in the [`report.pdf`] (https://github.com/amirghaffari/benchmark_riak/blob/master/report.pdf) file. The followings explain how to customize the scripts to match your specific environment.

Customization
------------
In the cluster each node can be either a trafﬁc generator or a Riak node. A trafﬁc generator runs one copy of the Basho Bench that generates and sends commands to the Riak nodes. A Riak node contains a complete and independent copy of the Riak package which is identiﬁed by an IP address and a port number.

The followings are configurable in the `run.sh` file:

*	Benchmark duration in minutes
*	The ratio of traffic generator nodes to Riak nodes
*	The Riak version
*	Number of times that an experiment repeats
*	Number of nodes that will leave and join back during the elastisity benchmark
	
The followings are configurable in the `experiment.sh` file:

*	The storage backend for Riak, i.e. Bitcask or eLevelDB 
*	Erlang path for compiling Riak and Basho Bench
*	R statistics language path which is needed for generating graphs
*	The name and IP address of the nodes in the cluster
	
There are two general config files for Basho Bench in the `basho_bench_config` directory, one for the HTTP interace and the other for the Protocol Buffers interface. The followings are configurable in the config files:

*	The number of worker process on each traffic generator node
*	Database commands (e.g. `get`, `insert`, `update`) used in the benchmark

How to run    
----------------------------------------

	$ git clone git://github.com/amirghaffari/benchmark_riak
	$ cd benchmark_riak
	After customizing the `run.sh` and `experiment.sh` files:
	$ ./run.sh 

