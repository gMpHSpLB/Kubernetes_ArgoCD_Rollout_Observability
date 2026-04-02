#Auto-start DB in pytest
#No manual docker command
#Tests are self-contained

#To achieve above
#    use testcontainers library : poetry add --group dev testcontainers psycopg2-binary2
import os
import pytest
import psycopg2

USE_TESTCONTAINERS = os.getenv("USE_TESTCONTAINERS", "false") == "true"

if USE_TESTCONTAINERS:
    from testcontainers.postgres import PostgresContainer

#Adding pytest fixture to auto start DB in pytest
#    Before tests → starts PostgreSQL container
#    After tests → stops automatically
@pytest.fixture(scope="session")
def db_connection():
    if USE_TESTCONTAINERS:
        with PostgresContainer("postgres:15") as postgres:
            conn = psycopg2.connect(
                host=postgres.get_container_host_ip(),
                port=postgres.get_exposed_port(5432),
                database="test",
                user="test",
                password="test",
            )
            yield conn
            conn.close()
    else:
        # Docker mode (use docker-compose DB)
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            database="mydb",
            user="myuser",
            password="mypassword",
            port=5432,
        )
        yield conn
        conn.close()