# Feijoa App - AWS EKS Demo

Welcome to the Feijoa App! This is an educational demonstration project for AWS Student Community Day in Auckland. This guide will walk you through containerizing a simple web application and deploying it to Amazon EKS (Elastic Kubernetes Service).

## What You'll Learn

- How to containerize applications using Docker
- How to store container images in AWS ECR (Elastic Container Registry)
- How to create and manage EKS clusters using eksctl
- How to deploy applications using Kubernetes manifests
- How to configure Ingress resources with IngressClass
- How to protect applications with PodDisruptionBudget
- The complete workflow from code to cloud deployment

## Prerequisites

Before starting this demo, ensure you have the following tools installed and configured:

### Required Tools

- **AWS CLI** (version 2.x)
  - Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  - Verify: `aws --version`

- **Docker** (version 27.x or later)
  - Install: https://docs.docker.com/get-docker/
  - Verify: `docker --version`
  - **Note for Mac Silicon users**: Docker Desktop includes Buildx by default for multi-platform builds

- **kubectl** (version 1.33 or later)
  - Install: https://kubernetes.io/docs/tasks/tools/
  - Verify: `kubectl version --client`

- **eksctl** (version 0.217.0 or later)
  - Install: https://eksctl.io/installation/
  - Verify: `eksctl version`

### AWS Account Requirements

You'll need an AWS account with the following IAM permissions:

- **ECR permissions**: `ecr:CreateRepository`, `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`
- **EKS permissions**: `eks:CreateCluster`, `eks:DescribeCluster`, `eks:DeleteCluster`, `eks:ListClusters`
- **IAM permissions**: Ability to create and manage IAM roles for EKS
- **VPC permissions**: Ability to create and manage VPC resources
- **EC2 permissions**: Ability to create and manage EC2 instances and security groups

**Note**: For simplicity, you can use an IAM user with `AdministratorAccess` policy for this demo, but in production environments, always follow the principle of least privilege.

### AWS Configuration

Ensure your AWS CLI is configured with credentials:

```bash
aws configure
```

You'll need to provide:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `ap-southeast-6` Asia Pacific (New Zealand)
- Default output format: `json`

Verify your configuration:

```bash
aws sts get-caller-identity
```

---

## Step 1: Create ECR Repository

First, create an ECR repository to store your container image. Replace `<account-id>` with your AWS account ID (you can find it in the output of `aws sts get-caller-identity`).

```bash
aws ecr create-repository --repository-name feijoa-app --region ap-southeast-6
```

---

## Step 2: Authenticate Docker to ECR

Before you can push images to ECR, you need to authenticate Docker with your ECR registry.

```bash
aws ecr get-login-password --region ap-southeast-6 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-6.amazonaws.com
```

**What this does**: 
- `aws ecr get-login-password` retrieves a temporary authentication token from ECR
- The token is piped to `docker login`, which authenticates your Docker client with the ECR registry
- This authentication is valid for 12 hours

**Success message**: You should see `Login Succeeded`

---

## Step 3: Build the Docker Image

Now let's build the container image from the Dockerfile. Since EKS runs on amd64 architecture and you may be on Mac Silicon (arm64), we'll build a multi-platform image.

### Option A: Multi-Platform Build (Recommended for Mac Silicon)

```bash
docker build --platform linux/amd64,linux/arm64 -t feijoa-app .
```

**What this does**:
- `--platform linux/amd64,linux/arm64` builds for both x86_64 and ARM64
- Ensures the image will run on EKS nodes (which use amd64) while also working locally on Mac Silicon
- Tags the image locally as `feijoa-app:latest`

### Option B: Single Platform Build (amd64 only)

If you only need to deploy to EKS and don't need to run locally on Mac Silicon:

```bash
docker build --platform linux/amd64 -t feijoa-app .
```

### Option C: Traditional Build (Local Architecture Only)

For non-Mac Silicon users or local testing only:

```bash
docker build -t feijoa-app .
```

**Expected output**: You'll see Docker executing each step, downloading the base image, installing dependencies, and copying files.

**Note for Mac Silicon users**: Using multi-platform builds ensures your image works both locally and on EKS. EKS nodes run on amd64 architecture, so the amd64 image is required for deployment.

---

## Step 4: Tag and Push the Image to ECR

Now we'll tag and push the image to ECR. For multi-platform images, we can build and push in one step.

### Option A: Build and Push Multi-Platform Image (Recommended for Mac Silicon)

```bash
docker build --platform linux/amd64,linux/arm64 \
  -t <account-id>.dkr.ecr.ap-southeast-6.amazonaws.com/feijoa-app:latest \
  --push .
```

**What this does**:
- Builds images for both amd64 (EKS) and arm64 (Mac Silicon) architectures
- Tags the image with the ECR repository URI
- Pushes both platform variants to ECR in one command
- The `--push` flag automatically pushes after building

### Option B: Traditional Tag and Push (Single Platform)

If you used the traditional `docker build` command:

```bash
# Tag the image
docker tag feijoa-app:latest <account-id>.dkr.ecr.ap-southeast-6.amazonaws.com/feijoa-app:latest

# Push to ECR
docker push <account-id>.dkr.ecr.ap-southeast-6.amazonaws.com/feijoa-app:latest
```

**What this does**:
- Creates a new tag for your existing image with the ECR repository URI
- Uploads your container image layers to ECR
- ECR stores the image securely in the ap-southeast-6 region
- The image becomes available for deployment to EKS

**Expected output**: You'll see progress bars as each layer is pushed. This may take a few minutes depending on your internet connection.

**Verify the push**:
```bash
aws ecr describe-images --repository-name feijoa-app --region ap-southeast-6
```

You should see your image listed with the `latest` tag. For multi-platform images, you'll see multiple manifests (one for each architecture).

---

## Step 6: Create EKS Cluster

Now let's create an EKS cluster using eksctl with auto mode enabled.

```bash
eksctl create cluster --name feijoa-app-cluster --region ap-southeast-6 --enable-auto-mode --version=1.34
```

**What this does**:
- Creates a new EKS cluster named "feijoa-app-cluster" in the Auckland region
- Enables EKS Auto Mode, which automatically manages compute resources
- Sets up VPC, subnets, security groups, and IAM roles
- Installs essential add-ons including the AWS Load Balancer Controller
- Configures kubectl to connect to your new cluster

**What EKS Auto Mode provides**:
- Automatic node group management
- Automatic scaling based on workload demands
- Pre-installed AWS Load Balancer Controller for Ingress support
- Simplified cluster configuration

**Expected creation time**: 10-15 minutes

**Monitor progress**: The command will show progress updates. Wait for the message "EKS cluster created successfully".

**Verify cluster creation**:
```bash
eksctl get cluster --name feijoa-app-cluster --region ap-southeast-6
kubectl cluster-info
```

---

## Step 7: Update Deployment Manifest

Before applying the Kubernetes manifests, you need to update the deployment with your AWS account ID.

Edit `kubernetes/deployment.yaml` and replace `<account-id>` with your actual AWS account ID in the image field:

```yaml
image: <account-id>.dkr.ecr.ap-southeast-6.amazonaws.com/feijoa-app:latest
```

---

## Step 8: Deploy the Application

Apply the Kubernetes manifests to deploy your application.

```bash
kubectl apply -f kubernetes/
```

**What this does**:
- Reads all YAML files in the `kubernetes/` directory
- Creates the following Kubernetes resources:
  - **Deployment**: Manages 2 replicas of your application pods
  - **Service**: Exposes your pods internally within the cluster
  - **IngressClass**: Defines the ingress controller to use (AWS Load Balancer Controller)
  - **Ingress**: Creates an AWS Application Load Balancer for external access
  - **PodDisruptionBudget**: Ensures minimum availability during voluntary disruptions (e.g., node maintenance)

**Expected output**:
```
deployment.apps/feijoa-app created
service/feijoa-app-service created
ingressclass.networking.k8s.io/feijoa-app-ingress-class created
ingress.networking.k8s.io/feijoa-app-ingress created
poddisruptionbudget.policy/feijoa-app-pdb created
```

**Verify deployment status**:
```bash
kubectl get deployments
kubectl get pods
```

Wait until all pods show `STATUS: Running` and `READY: 1/1`.

### Understanding the Kubernetes Resources

The deployment includes several Kubernetes resources that work together:

- **Deployment**: Manages the application pods, ensuring the desired number of replicas (2) are running. It handles rolling updates and pod restarts.

- **Service**: Provides a stable network endpoint for your pods. Other services in the cluster can reach your application using the service name `feijoa-app-service`.

- **IngressClass**: Defines which ingress controller should handle ingress resources. In this case, it specifies the AWS Load Balancer Controller (`k8s.aws/alb`) to create Application Load Balancers.

- **Ingress**: Creates an AWS Application Load Balancer that routes external HTTP traffic to your service. The ingress uses the IngressClass to determine which controller manages it.

- **PodDisruptionBudget (PDB)**: Ensures high availability by preventing too many pods from being terminated simultaneously during voluntary disruptions (like node maintenance or cluster upgrades). With `minAvailable: 1`, at least one pod will always remain running.

---

## Step 9: Access Your Application

Now let's verify that your application is running and accessible.

### Check All Resources

```bash
# View all resources at once
kubectl get all

# Check specific resources
kubectl get pods
kubectl get services
kubectl get deployments
kubectl get ingress
kubectl get ingressclass
kubectl get poddisruptionbudget
```

### Get the Load Balancer URL

The Ingress resource creates an AWS Application Load Balancer. Get its URL:

```bash
kubectl get ingress feijoa-app-ingress
```

Look for the `ADDRESS` column - this is your load balancer URL. It will look something like:
```
k8s-default-feijoaap-xxxxxxxxxx-yyyyyyyyyy.ap-southeast-6.elb.amazonaws.com
```

**Note**: It may take 2-3 minutes for the load balancer to be fully provisioned and the ADDRESS to appear. If you see `<pending>`, wait a moment and run the command again.

### Test the Application

Once you have the load balancer URL, test your application:

```bash
# Using curl
curl http://<load-balancer-url>/api/info

# Or open in your browser
open http://<load-balancer-url>
```

**Expected response**: You should see a JSON response with information about the Feijoa App, or the HTML page in your browser.

### Verify Health

```bash
curl http://<load-balancer-url>/health
```

You should see a healthy status response.

---

## Cleanup

**IMPORTANT**: To avoid ongoing AWS charges, make sure to clean up all resources when you're done with the demo.

### Step 1: Delete Kubernetes Resources

```bash
kubectl delete -f kubernetes/
```

This removes the Deployment, Service, IngressClass, Ingress, and PodDisruptionBudget. The AWS Load Balancer will be automatically deleted.

### Step 2: Delete the EKS Cluster

```bash
eksctl delete cluster --name feijoa-app-cluster --region ap-southeast-6
```

This will delete the cluster and all associated resources (VPC, subnets, security groups, IAM roles). This may take 10-15 minutes.

### Step 3: Delete ECR Repository (Optional)

If you want to completely clean up, you can also delete the ECR repository:

```bash
aws ecr delete-repository --repository-name feijoa-app --region ap-southeast-6 --force
```

The `--force` flag deletes the repository even if it contains images.

**Why cleanup is important**: 
- EKS clusters incur hourly charges
- Load balancers incur hourly charges
- ECR storage incurs monthly charges
- Proper cleanup prevents unexpected AWS bills

### Verify Cleanup

```bash
# Verify cluster is deleted
eksctl get cluster --region ap-southeast-6

# Verify ECR repository is deleted (if you deleted it)
aws ecr describe-repositories --region ap-southeast-6
```

---

## Troubleshooting

This section covers common issues you might encounter during the demo and how to resolve them.

### Docker Build Errors

**Problem**: `ERROR [internal] load metadata for docker.io/library/node:18-alpine`

**Solution**: Check your internet connection. Docker needs to download the base image from Docker Hub. If you're behind a proxy, configure Docker to use it.

---

**Problem**: `npm install` fails during build

**Solution**: Ensure `package.json` is present and valid. Check that you're running the build command from the project root directory.

---

**Problem**: `Cannot connect to the Docker daemon`

**Solution**: 
1. Ensure Docker Desktop is running
2. On Linux, start the Docker service: `sudo systemctl start docker`
3. Verify Docker is running: `docker ps`

---

**Problem**: `COPY failed: file not found`

**Solution**: Check that all files referenced in the Dockerfile exist in the build context. Ensure you're running `docker build` from the correct directory (project root).

---

**Problem**: Build is very slow or hangs

**Solution**: 
1. Check your internet connection speed
2. Clear Docker build cache: `docker builder prune`
3. Ensure you have sufficient disk space: `docker system df`

---

### ECR Authentication Errors

**Problem**: `no basic auth credentials`

**Solution**: Re-run the ECR login command. The authentication token expires after 12 hours.

```bash
aws ecr get-login-password --region ap-southeast-6 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-6.amazonaws.com
```

---

**Problem**: `User: arn:aws:iam::xxx:user/xxx is not authorized to perform: ecr:GetAuthorizationToken`

**Solution**: Your IAM user lacks ECR permissions. Add the `AmazonEC2ContainerRegistryFullAccess` policy or the specific ECR permissions listed in Prerequisites.

---

**Problem**: `An error occurred (RepositoryNotFoundException) when calling the PutImage operation`

**Solution**: The ECR repository doesn't exist. Create it first:
```bash
aws ecr create-repository --repository-name feijoa-app --region ap-southeast-6
```

---

**Problem**: `denied: Your authorization token has expired`

**Solution**: Your ECR login has expired (tokens last 12 hours). Re-authenticate:
```bash
aws ecr get-login-password --region ap-southeast-6 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-6.amazonaws.com
```

---

**Problem**: `Error saving credentials: error storing credentials`

**Solution**: Docker credential helper issue. Try logging in without the credential helper or reinstall Docker Desktop.

---

### EKS Cluster Creation Errors

**Problem**: `Error: checking AWS STS access`

**Solution**: Verify your AWS credentials are configured correctly:
```bash
aws sts get-caller-identity
aws configure list
```

If credentials are missing or incorrect, run `aws configure` again.

---

**Problem**: `Error: creating CloudFormation stack`

**Solution**: 
1. Check that you have sufficient IAM permissions for EKS, VPC, and EC2 resources
2. Ensure you're not hitting AWS service quotas (check AWS Service Quotas console)
3. Verify the region supports EKS: `aws eks list-clusters --region ap-southeast-6`

---

**Problem**: `Error: operation error EKS: CreateCluster, https response error StatusCode: 403`

**Solution**: Your IAM user/role lacks EKS permissions. Ensure you have `eks:CreateCluster` permission or use an admin account for the demo.

---

**Problem**: Cluster creation times out or fails after 20+ minutes

**Solution**: 
1. Check CloudFormation console for detailed error messages
2. Delete the failed stack: `eksctl delete cluster --name feijoa-app-cluster --region ap-southeast-6`
3. Try creating the cluster again
4. If it persists, try a different cluster name

---

**Problem**: `Error: AWS::EKS::Cluster/ControlPlane: CREATE_FAILED – "Resource handler returned message: Insufficient permissions"`

**Solution**: Your IAM user needs additional permissions. Ensure you have permissions to create IAM roles and policies, or use an account with `AdministratorAccess` for the demo.

---

### kubectl/Deployment Errors

**Problem**: `error: You must be logged in to the server (Unauthorized)`

**Solution**: Update your kubectl context to connect to the cluster:
```bash
aws eks update-kubeconfig --name feijoa-app-cluster --region ap-southeast-6
```

---

**Problem**: `The connection to the server localhost:8080 was refused`

**Solution**: kubectl is not configured to connect to your cluster. Run:
```bash
aws eks update-kubeconfig --name feijoa-app-cluster --region ap-southeast-6
kubectl config current-context
```

---

**Problem**: Pods stuck in `ImagePullBackOff` status

**Solution**: 
1. Check that you updated the deployment.yaml with your correct AWS account ID
2. Verify the image exists in ECR: `aws ecr describe-images --repository-name feijoa-app --region ap-southeast-6`
3. Check pod logs for detailed error: `kubectl describe pod <pod-name>`
4. Verify the image URI format is correct: `<account-id>.dkr.ecr.ap-southeast-6.amazonaws.com/feijoa-app:latest`

---

**Problem**: Pods stuck in `Pending` status

**Solution**: 
1. Check if nodes are ready: `kubectl get nodes`
2. Describe the pod to see events: `kubectl describe pod <pod-name>`
3. With EKS Auto Mode, nodes should provision automatically. Wait 2-3 minutes.
4. Check for resource constraints or scheduling issues in the pod description

---

**Problem**: Pods stuck in `CrashLoopBackOff` status

**Solution**: 
1. Check pod logs: `kubectl logs <pod-name>`
2. Check previous logs if pod restarted: `kubectl logs <pod-name> --previous`
3. Verify the application starts correctly locally: `docker run -p 3000:3000 feijoa-app`
4. Check for missing environment variables or configuration

---

**Problem**: Ingress ADDRESS shows `<pending>` for a long time

**Solution**: 
1. Wait 3-5 minutes - load balancer provisioning takes time
2. Check ingress events: `kubectl describe ingress feijoa-app-ingress`
3. Verify AWS Load Balancer Controller is running: `kubectl get pods -n kube-system | grep aws-load-balancer-controller`
4. Check ingress class exists and is correct: `kubectl get ingressclass feijoa-app-ingress-class`
5. Verify the ingress references the correct ingress class: `kubectl get ingress feijoa-app-ingress -o yaml | grep ingressClassName`

---

**Problem**: `error: unable to recognize "kubernetes/": no matches for kind "Ingress"`

**Solution**: Your Kubernetes version might not support the Ingress API version used. Check your cluster version:
```bash
kubectl version
```
Ensure you're using Kubernetes 1.19+ which supports `networking.k8s.io/v1` Ingress.

---

**Problem**: Service not accessible via load balancer

**Solution**: 
1. Verify ingress has an address: `kubectl get ingress`
2. Check service endpoints: `kubectl get endpoints feijoa-app-service`
3. Verify pods are running: `kubectl get pods`
4. Test service internally: `kubectl run test-pod --image=busybox --rm -it -- wget -O- http://feijoa-app-service:3000`
5. Check security groups in AWS console allow HTTP traffic

---

### Checking Cluster and Pod Status

Use these commands to diagnose issues:

**Check cluster information:**
```bash
# Get cluster details
eksctl get cluster --name feijoa-app-cluster --region ap-southeast-6

# Get cluster endpoint and status
kubectl cluster-info

# Check cluster nodes
kubectl get nodes

# Get detailed node information
kubectl describe nodes
```

**Check pod status:**
```bash
# List all pods
kubectl get pods

# Get detailed pod information
kubectl get pods -o wide

# Describe a specific pod (shows events and status)
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# View previous pod logs (if pod restarted)
kubectl logs <pod-name> --previous

# Follow pod logs in real-time
kubectl logs <pod-name> -f

# Check pod resource usage
kubectl top pods
```

**Check all resources:**
```bash
# View all resources in default namespace
kubectl get all

# View resources with labels
kubectl get all --show-labels

# Check events (useful for debugging)
kubectl get events --sort-by='.lastTimestamp'

# Check specific resource types
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get ingressclass
kubectl get poddisruptionbudget
kubectl get configmaps
kubectl get secrets
```

**Check EKS-specific resources:**
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check kube-system pods
kubectl get pods -n kube-system

# Check all namespaces
kubectl get pods --all-namespaces
```

**Network debugging:**
```bash
# Test service connectivity from within cluster
kubectl run test-pod --image=busybox --rm -it -- wget -O- http://feijoa-app-service:3000

# Check service endpoints
kubectl get endpoints

# Describe service
kubectl describe service feijoa-app-service

# Check ingress details
kubectl describe ingress feijoa-app-ingress
```

---

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [eksctl Documentation](https://eksctl.io/)
- [Builder Center](https://builder.aws.com/)

---

## About This Demo

This project was created for AWS Student Community Day in Auckland to teach university students about container orchestration and cloud deployment. The application is named after the feijoa, a delicious fruit widely grown in New Zealand!

**Region**: This demo uses the Asia Pacific (New Zealand) region, AWS's newest region located in New Zealand.

---

## License

MIT License - Feel free to use this demo for educational purposes.
