FROM docker.io/nextgenhealthcare/connect

# Download and copy the PostgreSQL JDBC driver
#ADD --chmod=644 https://jdbc.postgresql.org/download/postgresql-42.7.3.jar /opt/connect/custom-lib/postgresql-42.7.3.jar

#COPY entrypoint.sh /entrypoint.sh