# Mirth Connect High Availability Deployment

This project provides a containerized, high-availability deployment of Mirth Connect with PostgreSQL database backend on Red Hat OpenShift (ROSA).

## Architecture Overview

- **Mirth Connect**: Healthcare integration engine deployed as a containerized application
- **PostgreSQL Cluster**: High-availability database cluster with 3 replicas using Crunchy Data Postgres Operator
- **pgAdmin**: Web-based PostgreSQL administration interface

## Prerequisites

- Access to a Red Hat OpenShift cluster (ROSA recommended)
- `oc` CLI tool installed and configured
- `podman` installed (for custom image builds)
- Crunchy Data PostgreSQL Operator installed in the cluster

## Installation Steps

### 1. Login to OpenShift

```bash
oc login --token=<your-token> --server=<your-cluster-api-url>
```

### 2. Create Project Namespace

```bash
oc new-project mirth-connect-ha
```

### 3. Setup OpenShift Internal Registry

Enable the default route for the internal image registry:

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'
```

Wait for the route to be created (may take 30-60 seconds):

```bash
echo "Waiting for registry route to be created..."
until oc get route default-route -n openshift-image-registry &> /dev/null; do sleep 5; done
```

Set registry environment variables:

```bash
REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
PROJECT=$(oc project -q)
```

### 4. Build and Push Custom Image (Optional)

If you want to use a custom Mirth Connect image:

```bash
# Authenticate podman to the registry
TOKEN=$(oc whoami -t)
podman login --tls-verify=false -u openshift -p $TOKEN $REGISTRY

# Build and push the image
IMAGE=$REGISTRY/$PROJECT/mirth-connect:latest
podman build --no-cache -t $IMAGE .
podman push --tls-verify=false $IMAGE
```

### 5. Configure Security and Service Account

Create service account for Mirth Connect:

```bash
oc create serviceaccount mirth-connect-sa
```

Apply the custom Security Context Constraint (SCC):

```bash
oc apply -f mirth-connect-scc.yaml
```

Grant SCC to the service account:

```bash
oc adm policy add-scc-to-user mirth-connect-scc -z mirth-connect-sa -n mirth-connect-ha
```

Grant image pull permissions:

```bash
oc policy add-role-to-user system:image-puller system:serviceaccount:mirth-connect-ha:mirth-connect-sa -n mirth-connect-ha
```

### 6. Deploy PostgreSQL Cluster

Deploy a high-availability PostgreSQL cluster with 3 replicas:

```bash
oc apply -f postgres-cluster.yaml
```

**Cluster Specifications:**
- **Version**: PostgreSQL 15
- **Replicas**: 3 instances with anti-affinity rules
- **Storage**: 1Gi per instance
- **Backup**: Configured with pgBackRest
- **High Availability**: Patroni-managed with automatic failover

Wait for the cluster to be ready:

```bash
oc get postgrescluster my-postgres-cluster -n mirth-connect-ha
```

Retrieve the PostgreSQL password:

```bash
oc get secret my-postgres-cluster-pguser-postgres -n mirth-connect-ha -o jsonpath="{.data.password}" | base64 --decode
```

### 7. Deploy Mirth Connect

Choose the appropriate deployment configuration:

**For Local/Development:**
```bash
oc apply -f mirth-connect.yaml
```

**For AWS/Production:**
```bash
oc apply -f mirth-connect-aws.yaml
```

**Configuration Details:**
- **Database Driver**: PostgreSQL JDBC
- **Connection**: Points to `my-postgres-cluster-primary:5432`
- **Resources**: 512Mi-2Gi memory, 250m-1 CPU
- **Security**: Non-root user (UID 1000), dropped capabilities

### 8. Create Service and Route

Expose Mirth Connect with a service and route:

```bash
oc apply -f mirth-connect-service-route.yaml
```

Get the application URL:

```bash
oc get route mirth-connect -n mirth-connect-ha
```

### 9. Deploy pgAdmin (Optional)

Create service account for pgAdmin:

```bash
oc create serviceaccount pgadmin-sa
```

Grant anyuid SCC (required for pgAdmin):

```bash
oc adm policy add-scc-to-user anyuid -z pgadmin-sa
```

Deploy pgAdmin:

```bash
oc apply -f pgadmin.yaml
```

Get pgAdmin URL:

```bash
oc get route pgadmin -n mirth-connect-ha
```

## Accessing the Applications

### Mirth Connect

**Default Credentials:**
- **Username**: `admin`
- **Password**: `admin`

**URL**: Retrieve using:
```bash
echo "https://$(oc get route mirth-connect -n mirth-connect-ha -o jsonpath='{.spec.host}')"
```

### pgAdmin

**Credentials** (from `pgadmin.yaml`):
- **Email**: `brentjon@redhat.com`
- **Password**: `redhat123`

**URL**: Retrieve using:
```bash
echo "https://$(oc get route pgadmin -n mirth-connect-ha -o jsonpath='{.spec.host}')"
```

**Connecting to PostgreSQL from pgAdmin:**
1. Login to pgAdmin
2. Add new server:
   - **Host**: `my-postgres-cluster-primary`
   - **Port**: `5432`
   - **Database**: `postgres`
   - **Username**: `postgres`
   - **Password**: Use the password retrieved in step 6

## Management Commands

### Restart Mirth Connect Deployment

```bash
oc rollout restart deployment/mirth-connect
oc rollout status deployment/mirth-connect
```

### Check Deployment Status

```bash
oc get pods -n mirth-connect-ha
oc get deployments -n mirth-connect-ha
oc get services -n mirth-connect-ha
oc get routes -n mirth-connect-ha
```

### View Logs

**Mirth Connect:**
```bash
oc logs -f deployment/mirth-connect -n mirth-connect-ha
```

**PostgreSQL:**
```bash
oc logs -f my-postgres-cluster-instance1-<pod-suffix> -n mirth-connect-ha
```

**pgAdmin:**
```bash
oc logs -f deployment/pgadmin -n mirth-connect-ha
```

### Scale Mirth Connect

```bash
oc scale deployment/mirth-connect --replicas=3 -n mirth-connect-ha
```

## Troubleshooting

### Check User ID in Container

```bash
oc debug deployment/mirth-connect
# Inside debug pod:
id mirth
```

Expected output: `uid=1000(mirth) gid=1000(ubuntu) groups=1000(ubuntu)...`

### Verify PostgreSQL Connection

```bash
oc exec -it deployment/mirth-connect -- sh
# Inside container:
nc -zv my-postgres-cluster-primary 5432
```

### Check Security Context Constraints

```bash
oc get scc mirth-connect-scc
oc describe scc mirth-connect-scc
```

## Configuration Files

- `Dockerfile` - Custom Mirth Connect image definition
- `mirth-connect.yaml` - Local/development deployment
- `mirth-connect-aws.yaml` - AWS/production deployment
- `mirth-connect-scc.yaml` - Security Context Constraint
- `mirth-connect-service-route.yaml` - Service and Route configuration
- `postgres-cluster.yaml` - PostgreSQL cluster definition
- `pgadmin.yaml` - pgAdmin deployment

## High Availability Features

### PostgreSQL Cluster
- **3 replicas** with pod anti-affinity for distribution across nodes
- **Patroni** for automatic failover and leader election
- **pgBackRest** for backup and restore capabilities
- **Read-write split** capability using primary and replica services

### Scalability
- Mirth Connect can be scaled horizontally by increasing replicas
- PostgreSQL handles connection pooling for multiple Mirth instances
- Load balancing via OpenShift Service mesh

## Security Considerations

- Non-root containers with specific UIDs
- Dropped capabilities and seccomp profiles
- Secret management for sensitive credentials
- TLS-enabled routes for external access
- Custom SCC with minimal required permissions

## Next Steps

1. Change default passwords for Mirth Connect and pgAdmin
2. Configure Mirth Connect channels and interfaces
3. Set up monitoring and alerting
4. Configure backup schedules for PostgreSQL
5. Review and harden security settings for production

## Support and Documentation

- [Mirth Connect Documentation](https://docs.nextgen.com/mirth/)
- [Crunchy Data PostgreSQL Operator](https://access.crunchydata.com/documentation/postgres-operator/)
- [OpenShift Documentation](https://docs.openshift.com/)

---

**Note**: Update the PostgreSQL password in `mirth-connect-aws.yaml` with the actual password from the secret before deploying to production.