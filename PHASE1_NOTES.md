### Mohamed Adel Kamal, ID: 20230343 notes

#### when i tried to run the setup script for installing everything, i went into the following issues:

1- redis service does not want to run due to a dynamic linkable object file called libz.so,
one of my projects that is writen in cpp i was contributing to downloaded this library locally in usr/local/lib
and made it as a sym link instead that points to a .bak file, redis service was using this instead of the global one
which ended up making it failing and not wanting to run, i had to remove that file on my own to make it run

also had to add this folder to the redis group by running this
`sudo chown -R redis:redis /var/log/redis`

### Nouran Mahmoud Hegazy, ID: 20231220 notes

#### Problem 1 — MongoDB repository compatibility with ubuntu versions

The `setup.sh` script originally hardcoded the Ubuntu `noble` (Ubuntu 24.04) codename for the MongoDB 8.0 repository.

I use Ubuntu 22.04 (Jammy), so the hardcoded repository configuration was not suitable for my environment.

We checked the MongoDB 8.0 repository support and determined that the setup script needs to account for the Ubuntu versions supported by the project.

##### Fix

Updated `setup.sh` to detect the Ubuntu version and select the appropriate MongoDB repository codename:

- Ubuntu 22.04 → `jammy`
- Ubuntu 24.04 → `noble`
- Ubuntu 25.10 → `noble` (MongoDB does not provide a native Questing repository)

Unsupported Ubuntu versions are rejected with an error message.

##### Testing

Tested the setup script on Ubuntu 22.04.5 LTS (Jammy). The script selected the `jammy` MongoDB repository and completed successfully.

#### Problem 2 — Missing `eventhub_catalog` database

The legacy catalog service expected a MySQL database named `eventhub_catalog`, but the database had not been initialized yet.

When checking the available databases, `eventhub_catalog` was not present.

##### Investigation

The project provides a MySQL seed file at:

```text
db-seed/mysql-seed.sql
```

The seed creates the `eventhub_catalog` database, the `catalog_event` table, and the initial catalog events.

##### Fix

The following command was used to initialize the database:

```bash
sudo mysql < db-seed/mysql-seed.sql
```

The database and table were then verified successfully, along with the four sample catalog events.

---

#### Problem 3 — MySQL root authentication mismatch

The project configuration expects the MySQL root user to connect using password authentication:

```text
spring.datasource.username=root
spring.datasource.password=rootpassword
```

However, the local MySQL `root` account was configured to use `auth_socket` authentication.

When attempting to run the seed with:

```bash
mysql -u root -p < db-seed/mysql-seed.sql
```

MySQL returned:

```text
ERROR 1698 (28000): Access denied for user 'root'@'localhost'
```

##### Investigation

The authentication plugin for the local root account was checked with:

```bash
sudo mysql -e "SELECT user, host, plugin FROM mysql.user WHERE user='root';"
```

The result showed:

```text
root | localhost | auth_socket
```

This means the local root account was using socket-based authentication rather than the password authentication expected by the project's configuration.

##### Fix

The seed was successfully imported using:

```bash
sudo mysql < db-seed/mysql-seed.sql
```

This uses the locally configured authentication method for the MySQL root account.

The legacy catalog application subsequently connected to MySQL successfully and started normally.

---

#### Problem 4 — Running Maven from the wrong directory

Initially, `mvn spring-boot:run` was executed from the project root rather than from the legacy catalog service directory.

Maven returned:

```text
No plugin found for prefix 'spring-boot'
```

##### Fix

The command was run from the service directory:

```bash
cd services/legacy-catalog-java
mvn spring-boot:run
```

The application then started successfully on port `8081`.

##### Verification

The service was successfully started using the new `run-catalog.sh` script, and the catalog API was accessible through:

```bash
curl http://localhost:8081/api/catalog
```

The root URL `/` returning a `404` was **not considered a problem**, because the service does not define a root endpoint. The defined catalog endpoints are under `/api/catalog`.

#### Problem 5: — Go version mismatch

setup.sh installed Go 1.18 on my Ubuntu 22.04 environment.

Impact: go mod tidy failed because the project requires Go 1.22.

Investigation: checked go version, which go, go env, apt policy golang-go, and go.mod.

Workaround: installed Go 1.22.12 locally.

Potential project fix: update setup.sh to install/provide a compatible Go version.
