# Mosso
Mosso: speed up distributed system testing via abstract state space prioritization

## Prerequisite
JDK 8

Maven 3.6.2

Python 3

### Build testing server
We enter the server directory, and build the project by
```bash
mvn clean package
```

A jar file "server-0.1-SNAPSHOT.jar" is generated in "target/".

## Use Mosso to generate prioritized test cases
We add TLC command line parameters "-dump dot,colorize,actionlabels
state" to generate a state.dot file containing the state space graph. 
Then, we use
```python
py path_generator.py $END_STATE$ $dir/to/state.dot$ $OUTPUT_PATH$ $dir/to/rules$ 
```
to traverse the whole graph. In the directory `OUTPUT_PATH`, you can
find two files, i.e., `ep.node` storing all nodes with an ID and state
values, and `ep.edge` storing all paths consisting of edges.

## Test generated cases by Mosso
First, we start the testing server by running the jar independently.
```bash
java -jar server-0.1-SNAPSHOT.jar -rootDir=$ROOT_DIR$       #The root directory of SUT.
                                  -port=$PORT$              #The server port.
                                  -cluster=$IP1$:$PORT1$    #The cluster setting.
                                           $IP2$:$PORT2$,
                                           ...
                                  -guidance=$GUIDENCE_DIR$     #The directory to store guidance files
                                  -nodeStarter=$NODE_DIR$      #The node start script
                                  -faults=$FAULT_TYPE$         #The fault types to be injected.
                                  -clientRequests=$LL$:$FILE$, #The client requests and corresponding script file.
                                                  $LC$:$FILE$
```

Then, to perform the runtime instrumentation, we add the jar as a java agent in the SUT initialization script.
```bash
$JAVA_HOME/bin/java  -Xbootclasspath/a:server-0.1-SNAPSHOT.jar -javaagent:server-0.1-SNAPSHOT.jar SUT.main.class
```

Finally, the testing can be automatically performed to find inconsistencies between the TLA+ specification and
implementations.
