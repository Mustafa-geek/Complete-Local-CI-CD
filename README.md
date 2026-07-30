# three-tier-userinfo-project
3 tier application which has front end , backend and database, front end using nginx (mount our inde.html file with nginx index.html file), in backend java code is  there, compile this java code and generate .jar, and used this jar file for deployment , deployment have done using docker compose.


Project Explaination:
    -   in front end we have UI for user information, if we saved user info from front end . it store into database, through backend. 

Front End:
    -   my custome index.html file is mount to nginx index.html file 
        also mount custome nginx.conf wiht original nginx nginx.conf file
bakend:
    -   code written in java. and I have write Multistage Docker File
    -   first stage --> compile the code and generet artifact (.jar) file using  maven 3.9 and only jar file copy from first stage to 2nd  stage 
    -   in 2nd stage we run this jar file  and expose it to  8080
database:
    -   i run mysql data  base container from docker-compose.yml file
        we need database to store some data from front end to database.

Command TO run:
1. DELETE all prvously running container from compose
        -   docker-compose down

2. BUILD THE IMAGE USE 
        -   docker-compose build --no-cache
                "--no-cache" is used to build from scrach, no take previus data 

3. AFTER BUILDING IMAGE RUN COMPOSE
        -   docker-compose up -d 
                "-d is used to run the command in background"

###### Pre-requisits #######
1. java 17 
2. mavane 3.9
3. docker 
4. docker compose

