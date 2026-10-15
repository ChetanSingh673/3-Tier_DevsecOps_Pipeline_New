# External Secrets Operator (ESO) - AWS Secrets Manager
Kubernetes manifests for syncing database credentials from AWS Secrets Manager into Kubernetes Secrets using the External Secrets Operator (ESO) with IRSA authentication.

**Prerequisites**

Install kubectl Refer https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

* Install eksctl
```bash
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

* Install helm
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
```

* Create an EKS Cluster
```bash
eksctl create cluster --name my-cluster --region ap-south-1 --node-type t3.medium --version 1.35
```

* External Secrets Operator installed in the cluster
```bash
sudo helm repo add external-secrets https://charts.external-secrets.io
sudo helm repo update
sudo helm install external-secrets external-secrets/external-secrets --namespace external-secrets --create-namespace --set installCRDs=true
```

* Install EBS CSI Controller
```bash
aws iam attach-role-policy \
--role-name <NodeInstanceRoleName> \
--policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
```
```bash
# Commnad to check if csi and controller driver is installed or not
sudo kubectl get pods -n kube-system | grep ebs-csi
```
If using a KMS customer-managed key, add kms:Decrypt permission on the KMS key ARN

**Files**
|File	| Description
| :--- | :--- |
service-account.yaml |	ServiceAccount annotated with the IAM role ARN for IRSA
cluster-secret-store.yaml	| ClusterSecretStore connecting ESO to AWS Secrets Manager in ap-south-1
external-secret.yaml |	ExternalSecret that syncs prod/db-credentials into a Kubernetes Secret
mongo-service.yaml |	Headless Service for MongoDB StatefulSet DNS discovery
mongo-statefulset.yaml |	MongoDB 3-node replica set StatefulSet using ESO-synced credentials

# Setup

**1. Create the secret in AWS Secrets Manager**
```bash
sudo aws secretsmanager create-secret \
  --name prod/db-credentials \
  --region ap-south-1 \
  --secret-string '{"POSTGRES_USER":"chetan_user","POSTGRES_PASSWORD":"chetan1234","POSTGRES_DB":"chetan_db"}'
```
```bash
# verify the secret
aws secretsmanager describe-secret \
  --secret-id prod/db-creds \
  --region ap-south-1
```
**2. Enable OIDC provider for the EKS cluster**
```bash
# Check if OIDC is already associated
aws eks describe-cluster --name my-cluster --region ap-south-1 \
  --query "cluster.identity.oidc.issuer" --output text

# If not, create the OIDC provider
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --region ap-south-1 \
  --approve
```
**3. Create the IAM policy**
```bash
aws iam create-policy \
  --policy-name ESO-SecretsManager-Policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        "Resource": "arn:aws:secretsmanager:ap-south-1:<ACCOUNT_ID>:secret:prod/db-credentials-*"
      }
    ]
  }'
```

**4. Create the IAM role with trust policy**
```bash
# Get your OIDC provider ID
OIDC_ID=$(aws eks describe-cluster --name my-cluster --region ap-south-1 \
  --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)

# Create the role
aws iam create-role \
  --role-name ESO-SecretsManager-Role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/'$OIDC_ID'"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "oidc.eks.ap-south-1.amazonaws.com/id/'$OIDC_ID':sub": "system:serviceaccount:external-secrets:external-secrets-sa",
            "oidc.eks.ap-south-1.amazonaws.com/id/'$OIDC_ID':aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  }'

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name ESO-SecretsManager-Role \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/ESO-SecretsManager-Policy
```

**5. Update placeholders**

In service-account.yaml, replace:

<ACCOUNT_ID> — your AWS account ID
<ESO_IAM_ROLE_NAME> — the IAM role name created for ESO
In external-secret.yaml, update:

namespace — the namespace where your application runs
remoteRef.key — if your secret name differs from prod/db-credentials

**6. Verify ESO**
```bash
# Check the ClusterSecretStore status
kubectl get clustersecretstore aws-secrets-manager

# Check the ExternalSecret sync status
kubectl get externalsecret -n three-tier db-credentials

# Verify the Kubernetes Secret was created
sudo kubectl get secret -n three-tier db-credentials -o jsonpath='{.data.POSTGRES_USER}' | base64 -d
sudo kubectl get secret -n three-tier db-credentials -o jsonpath='{.data.POSTGRES_DB}' | base64 -d
sudo kubectl get secret -n three-tier db-credentials -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

```

**6. Verify PostgresDB**
```bash
sudo kubectl exec -it blog-db-0 -n three-tier -- sh
/ # psql -U chetan_user -d chetan_db
psql (16.15)
Type "help" for help.

chetan_db=# \conninfo
You are connected to database "chetan_db" as user "chetan_user" via socket in "/var/run/postgresql" at port "5432".

chetan_db=# \dt
            List of relations
 Schema |   Name   | Type  |    Owner
--------+----------+-------+-------------
 public | comments | table | chetan_user
 public | posts    | table | chetan_user
(2 rows)


chetan_db=# select * from comments;
 id | post_id | author |  content   |         created_at
----+---------+--------+------------+----------------------------
  1 |       1 | Chetan | Nice One!! | 2026-10-15 09:02:40.110416
(1 row)

chetan_db=# select * from posts;
 id |           title           |   content   | author | emoji |         created_at         |         updated_at
----+---------------------------+-------------+--------+-------+----------------------------+----------------------------
  1 | This is the first comment | Hello World | Chetan | ✨    | 2026-10-15 09:02:21.644363 | 2026-10-15 09:02:21.644363
(1 row)
```
