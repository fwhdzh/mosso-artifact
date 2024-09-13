rm -rf ~/.m2/repository/com/github/wenweihu86/
mvn clean package
cd raft-java-core
mvn clean install:install-file -Dfile=/home/dong/Documents/MCDT/Mocket/target/Mocket-0.1-SNAPSHOT-jar-with-dependencies.jar -DgroupId=iscas.tcse -DartifactId=Mocket -Dversion=0.1-SNAPSHOT -Dpackaging=jar -DskipTests
mvn clean install
cd -
cd raft-java-example
mvn clean package
cd -
