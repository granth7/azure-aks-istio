#  Setup terraform

1. Docs are from https://learnk8s.io/terraform-aks
2. cd C:\git\azure-aks-istio
3. install https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
```
az login
```
4. install terraform (run as admin)
```
choco install terraform
```
5. in mingw64, get the credentials:
```
az account list | grep -oP '(?<="id": ")[^"]*'
c034446e-d5dc-4fb0-b1fd-a8404b71f6b8
```
6. In a normal cmd window run:
```
az account set --subscription="c034446e-d5dc-4fb0-b1fd-a8404b71f6b8"
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/c034446e-d5dc-4fb0-b1fd-a8404b71f6b8"
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "azure-cli-2021-02-13-20-01-37",
  "name": "http://azure-cli-2021-02-13-20-01-37",
  "password": "0000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```
7. Install istioctl from https://istio.io/latest/docs/setup/getting-started/#download and put it in `C:\ProgramData\chocolatey\bin\`
8. If you are using neon (https://github.com/nforgeio/neonSDK) for password management, run the following command to setup your password `neon tool password set hendertech-devops`. Then setup your vault by running from this path: .\azure-aks-istio `neon tool vault create terraform_env.txt hendertech-devops`. If you already have a vault setup then type `neon tool vault edit terraform_env.txt` and paste in the following. The terraform provider will know how to read those environment variables. 
```
set ARM_CLIENT_ID=<insert the appId from above>
set ARM_SUBSCRIPTION_ID=<insert your subscription id>
set ARM_TENANT_ID=<insert the tenant from above>
set ARM_CLIENT_SECRET=<insert the password from above>
```
9. Open your environment variables from the vault via `neon tool vault edit terraform_env.txt` and paste in the contents from Notepad into your terminal to set your environment variables.
10. Follow these instructions: https://stackoverflow.com/questions/70851465/azure-ad-group-authorization-requestdenied-insufficient-privileges-to-complet
11. Rename your .kube folder to .kube.current so that you will only see what is imported in lens (installed in step 16).
12. Run `terraform init` from .\azure-aks-istio  if you haven't ran init yet, then:
```
terraform plan
terraform apply
```
13. Go into azure and create a custom role via Access your subscription, IAM, Add, Custom Role, paste in the json in the json tab
```
{
    "properties": {
        "roleName": "role_assignment_write_delete",
        "description": "Allow role to write and delete roles in this subscription",
        "assignableScopes": [
            "/subscriptions/<your-subscription-id>"
        ],
        "permissions": [
            {
                "actions": [
                    "Microsoft.Authorization/roleAssignments/write",
                    "Microsoft.Authorization/roleAssignments/delete"
                ],
                "notActions": [],
                "dataActions": [],
                "notDataActions": []
            }
        ]
    }
}
```
14. Add, Role Assignment, choose role role_assignment_write_delete, add members, search fore azure-cli, add the assignment
15. You may have to run `terraform apply` twice
16. Install Lens (https://k8slens.dev/)
17. In Lens, File => Add Cluster, and paste in the `kubeconfig` file that was generated when you ran terraform apply
18. In Lens: get the external ip via `kubectl get svc istio-ingressgateway -n istio-system`
```
NAME                   TYPE           CLUSTER-IP   EXTERNAL-IP    PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.0.21.44   20.252.13.28   15021:32186/TCP,80:31502/TCP,443:30900/TCP   26m
```
19. Setup your hosts file to point a dns name to the external ip listed in the prior step, e.g. `20.252.13.28	hender.tech`

20. To apply secrets manually for cert-manager, run
```
kubectl create secret generic -n istio-system cloudflare-api-key-secret --from-literal=API="<YOUR_API_KEY>"
```

21. If you change anything with cert manager, make sure to delete certificates AND the clusterIssuer to remove all resources before re-running terraform apply.


22. Navigate to http://hender.tech. If the page does not load then check to make sure all the deployments were actually deployed, make sure the pods are running, etc


23. Push images to the registry
```
docker login hendertechregistry.azurecr.io  # You can get the login URI and credentials from Access keys blade in the azure portal
docker pull registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3
docker tag registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 hendertechregistry.azurecr.io/jessie-dnsutils:1.3
docker push hendertechregistry.azurecr.io/jessie-dnsutils:1.3
```
24. Create the image pull secrets. For the `docker-password`, use the same credentials you used for docker login
```
kubectl create secret docker-registry hendertech-registry --namespace default --docker-server=hendertechregistry.azurecr.io --docker-username=hendertechRegistry --docker-password=<service-principal-password>
```

# azure-aks-istio

https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/_examples/aks/

# To restart from scratch, delete the following:
.terraform
.istio
kube-cluster
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup

Then run 
terraform init
terrraform plan

# Deploying an Azure Point to Site VPN Gateway using Terraform
From https://github.com/guillermo-musumeci/azure-terraform-point-to-site-vpn-gateway

# To destroy, run:
terraform destroy

# Troubleshooting
1. To update a chart you can use Lens and run `helm list --namespace yournamespace` to find the chart and `helm uninstall --namespace yournamespace` and then run `terraform apply` to update the chart. It doesn't seem like terraform will reapply a chart once it's been installed.