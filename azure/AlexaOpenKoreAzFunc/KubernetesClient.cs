using KubeClient;
using KubeClient.Models;
using Microsoft.Extensions.Logging;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace AlexaOpenKoreAzFunc
{
    public class KubernetesClient
    {
        ILogger log;
       
        public KubernetesClient (ILogger log)
        {
            this.log = log;
        }

        public async Task<int> Scale(int numberOfPods, string k8sApiUri, string k8sBearerToken, string k8sDeploymentName)
        {
            try
            {
                KubeClientOptions options = new KubeClientOptions()
                {
                    ApiEndPoint = new Uri(k8sApiUri), //Change this for your own API URI
                    AuthStrategy = KubeAuthStrategy.BearerToken,
                    AccessToken = k8sBearerToken, //Change this for your own Bearer
                    AllowInsecure = true 
                };

                using (KubeApiClient client = KubeApiClient.Create(options))
                {
                    var deployments = await client.DeploymentsV1().List();
                    var currentDeployment = deployments.First(i=>i.Metadata.Name == k8sDeploymentName); //change first for the real one (rathena-openkore-cognitive)
                    DeploymentV1 updatedDeployment = await UpdateDeployment(client, currentDeployment, numberOfPods);
                }

                return ExitCodes.Success;
            }
            catch (Exception unexpectedError)
            {
                log.LogError("[ERROR] K8s unable to scale deployment: " + unexpectedError.ToString());
                return ExitCodes.UnexpectedError;
            }
        }

        static async Task<DeploymentV1> UpdateDeployment(IKubeApiClient client, DeploymentV1 existingDeployment, int numberOfPods)
        {
            DeploymentV1 updatedDeployment = await client.DeploymentsV1().Update(existingDeployment.Metadata.Name, kubeNamespace: existingDeployment.Metadata.Namespace, patchAction: patch =>
            {
                patch.Replace(
                    path: deployment => deployment.Spec.Replicas,
                    value: numberOfPods
                );
            });

            updatedDeployment = await client.DeploymentsV1().Get(updatedDeployment.Metadata.Name, updatedDeployment.Metadata.Namespace);
            return updatedDeployment;
        }

        public static class ExitCodes
        {
            public const int Success = 0;
            public const int InvalidArguments = 1;
            public const int NotFound = 10;
            public const int UnexpectedError = 50;
        }
    }
}
