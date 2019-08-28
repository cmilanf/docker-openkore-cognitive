using System;
using System.IO;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Collections.Async;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Microsoft.Azure.Storage;
using Microsoft.Azure.Storage.Queue;
using Newtonsoft.Json;
using Alexa.NET.Request;
using Alexa.NET.Request.Type;
using Alexa.NET;
using Alexa.NET.Response;
using System.Net.Sockets;
using MySql.Data.MySqlClient;

namespace AlexaOpenKoreAzFunc
{
    public static class Function1
    {
        [FunctionName("AlexaOpenKoreAzFunc")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req,
            ILogger log, ExecutionContext context)
        {
            string json = await req.ReadAsStringAsync();
            var skillRequest = JsonConvert.DeserializeObject<SkillRequest>(json);
            var requestType = skillRequest.GetRequestType();
            string launchResponseStr = "¡Hola a todos! ¡Es un honor estar en la Global Azure Bootcamp!";

            var appSettings = new ConfigurationBuilder()
                .SetBasePath(context.FunctionAppDirectory)
                .AddJsonFile("local.settings.json", optional: true, reloadOnChange: true)
                .AddEnvironmentVariables()
                .Build();
            string dbIpAddress = appSettings["MYSQL_HOST"];
            int dbTcpPort = Convert.ToInt32(appSettings["MYSQL_PORT"]);
            string serverIpAddress = appSettings["SERVER_HOST"];
            int serverTcpPort = Convert.ToInt32(appSettings["SERVER_PORT"]);
            string dbConnStr = appSettings.GetConnectionString("rAthenaDbConnStr");
            string queueConnStr = appSettings.GetConnectionString("storageQueueConnStr");
            string k8sApiUri = appSettings["K8S_API_ENDPOINT"];
            string k8sBearerToken = appSettings["K8S_BEARER_TOKEN"];
            string k8sDeploymentName = appSettings["K8S_DEPLOYMENT_NAME"];
            log.LogInformation("[INFO] AppSetting => rAthenaDbConnStr: " + dbConnStr);

            SkillResponse response = null;

            log.LogInformation("[INFO]: Request initiated");

            if(requestType == typeof(LaunchRequest))
            {
                bool dbConnectionCheck = TestTcpPortAvailability(dbIpAddress, dbTcpPort);
                bool serverConnectionCheck = TestTcpPortAvailability(serverIpAddress, serverTcpPort);
                bool responseShouldEndSession = false;
                log.LogInformation("[INFO]: LaunchRequest initiated");

                if(dbConnectionCheck && serverConnectionCheck)
                {
                    launchResponseStr += " He podido conectarme correctamente tanto a la base de datos como al" +
                        " servidor del videojuego, pero Alberto y Carlos son un poco vagonetis y sólo han " +
                        "comprobado si algo escucha protocolo TCP en el otro extremo. Ya les he dicho que eso " +
                        "no es garantía de nada, así te lo digo Hulio.";
                    log.LogInformation("[INFO]: Successfully checked database and server connection.");
                } else if (dbConnectionCheck && !serverConnectionCheck)
                {
                    launchResponseStr += " He podido conectarme a la base de datos, pero no al servidor del juego. " +
                        "La IP del servidor es " + serverIpAddress + ", puerto TCP " + serverTcpPort.ToString() + ". " +
                        "Llámame de nuevo cuando soluciones el problema. ¡Hasta lueguito guapi!";
                    log.LogError("[ERROR]: Cannot connect to server.");
                    responseShouldEndSession = true;
                } else if (!dbConnectionCheck && serverConnectionCheck)
                {
                    launchResponseStr += " He podido conectarme al servidor del juego, pero no a la base de datos. " +
                        "La IP de la base de datos es " + dbIpAddress + ", puerto TCP " + dbTcpPort.ToString() + ". " +
                        "Llámame de nuevo cuando soluciones el problema. ¡Hasta lueguito guapi!";
                    responseShouldEndSession = true;
                    log.LogError("[ERROR]: Cannot connect to database.");
                } else
                {
                    launchResponseStr += " No he podido conectarme ni a la base de datos ni al servidor del juego. " +
                        "Sin ellos no puedo hacer mucho por tí. He intentado conectarme a la base de datos en la IP " +
                        dbIpAddress + ", puerto TCP " + dbTcpPort.ToString() + "; y al servidor del juego en la IP " +
                        serverIpAddress + ", puerto TCP " + serverTcpPort.ToString() + ". Llámame de nuevo cuando " +
                        "hayas solucionado el problema. ¡Hasta lueguito guapi!";
                    responseShouldEndSession = true;
                    log.LogError("[ERROR]: Cannot connect to database or server.");
                }
                response = ResponseBuilder.Tell(launchResponseStr);
                response.Response.ShouldEndSession = responseShouldEndSession;
            } else if (requestType == typeof(IntentRequest))
            {
                var intentRequest = skillRequest.Request as IntentRequest;
                int numberResult = -255;

                switch (intentRequest.Intent.Name)
                {
                    case "CurrentNumberIntent":
                        log.LogInformation("[INFO] CurrentNumberIntent");
                        response = ResponseBuilder.Tell("Socio, hay un total de " + CurrentBotNumber(dbConnStr, log).ToString() +
                            " bots conectados.");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "SitIntent":
                        log.LogInformation("[INFO] SitIntent");
                        numberResult = IssueCommandToOnlineBots("sit", dbConnStr, queueConnStr, log);
                        response = ResponseBuilder.Tell("He ordenado a " + numberResult.ToString() + " bots que se sienten.");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "StandupIntent":
                        log.LogInformation("[INFO] StandupIntent");
                        numberResult = IssueCommandToOnlineBots("stand", dbConnStr, queueConnStr, log);
                        response = ResponseBuilder.Tell("He ordenado a " + numberResult.ToString() + " bots que se levanten.");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "ScaleIntent":
                        log.LogInformation("[INFO] ScaleIntent");
                        var numOfBotsStr = intentRequest.Intent.Slots["number"].Value;            
                        numberResult = await ScaleCommandToBots(numOfBotsStr, k8sApiUri, k8sBearerToken, k8sDeploymentName, log);
                        response = ResponseBuilder.Tell("¡Llamando al ejercito! Has pedido escalar a: " + numOfBotsStr + " bots");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "ReunitedIntent":
                        log.LogInformation("[INFO] ReunitedIntent");
                        numberResult = IssueCommandToOnlineBots("move 290 185", dbConnStr, queueConnStr, log);
                        response = ResponseBuilder.Tell("He ordenado a los bots moverse al punto de reunión");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "AttackIntent":
                        log.LogInformation("[INFO] AttackIntent");
                        numberResult = IssueCommandToOnlineBots("a yes", dbConnStr, queueConnStr, log);
                        log.LogInformation("[INFO] AttackIntent, command issued to " + numberResult.ToString() + " bots");
                        response = ResponseBuilder.Tell("¡DRAKARIS!");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "NoAttackIntent":
                        log.LogInformation("[INFO] NoAttackIntent");
                        numberResult = IssueCommandToOnlineBots("a no", dbConnStr, queueConnStr, log);
                        numberResult = IssueCommandToOnlineBots("as", dbConnStr, queueConnStr, log);
                        response = ResponseBuilder.Tell("He ordenado a " + numberResult.ToString() + " botijos que se vuelvan unos pacifistas");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "EmotionWhistleIntent":
                        log.LogInformation("[INFO] EmotionWhistleIntent");
                        numberResult = IssueCommandToOnlineBots("e ho", dbConnStr, queueConnStr, log);
                        response = ResponseBuilder.Tell("He ordenado a " + numberResult.ToString() + " botijos que silben");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "EmotionHearthIntent":
                        log.LogInformation("[INFO] EmotionHearthIntent");
                        numberResult = IssueCommandToOnlineBots("e lv", dbConnStr, queueConnStr, log);
                        response = ResponseBuilder.Tell("Le he pedido " + numberResult.ToString() + " botijos que expresen lo que piensan");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "EmotionIdeaIntent":
                        log.LogInformation("[INFO] EmotionIdeaIntent");
                        numberResult = IssueCommandToOnlineBots("e ic", dbConnStr, queueConnStr, log);
                        response = ResponseBuilder.Tell("Veamos si alguno de los " + numberResult.ToString() + " botijos tiene una idea");
                        response.Response.ShouldEndSession = true;
                        break;
                    case "AMAZON.HelpIntent":
                        response = ResponseBuilder.Tell("Hola guapis, bienvenidos a la app de Alexa para Global Azure Bootcamp 2019. Me " +
                            "habéis pedido ayuda y seguro que ni siquiera habéis buscado en Google o Stackoverflow, y si ya hablamos de " +
                            "leer el -piiiiiiiii- manual ni os cuento. Así que os voy a dar el conocimiento para acceder al power: abrid" +
                            " un navegador, entráis en www.google.com y escribís lo que queráis saber. Ahí lo lleváis, por ser vosotros" +
                            " os lo dejo en un bitcoin.");
                        response.Response.ShouldEndSession = false;
                        break;
                    case "AMAZON.StopIntent":
                    case "AMAZON.CancelIntent":
                        response = ResponseBuilder.Tell("Hasta lueguito guapis");
                        response.Response.ShouldEndSession = true;
                        break;
                    default: break;
                }
            }

            return new OkObjectResult(response);
        }

        // https://stackoverflow.com/questions/17118632/how-to-set-the-timeout-for-a-tcpclient
        public static bool TestTcpPortAvailability (string ipAddress, int port)
        {
            var client = new TcpClient();
            var result = client.BeginConnect(ipAddress, port, null, null);

            var success = result.AsyncWaitHandle.WaitOne(TimeSpan.FromSeconds(3));
            if (!success)
            {
                return false;
            } else
            {
                client.EndConnect(result);
                return true;
            }
        }

        public static int CurrentBotNumber(string dbConnStr, ILogger log)
        {
            string sqlQuery = "SELECT COUNT(*) FROM `char` WHERE online = 1";
            var conn = new MySqlConnection();
            conn.ConnectionString = dbConnStr;
            var cmd = new MySqlCommand(sqlQuery, conn);
            int count = -1;

            try
            {
                log.LogInformation("[INFO]: Opening database connection...");
                conn.Open();
                log.LogInformation("[INFO]: Executing query '" + sqlQuery);
                count = Convert.ToInt32(cmd.ExecuteScalar());
            } catch (Exception ex)
            {
                log.LogError("[ERROR] Database connection error: " + ex.Message);
            } finally
            {
                conn.Close();
            }

            return count;
        }

        public static int IssueCommandToOnlineBots (string command, string dbConnStr, string queueConnStr, ILogger log)
        {
            try
            {
                List<string> onlineBotList = GetRathenaOnlineChars(dbConnStr, log, "botijo");
                log.LogInformation("[INFO] Attempting to issue command to " + onlineBotList.Count.ToString() + " bots.");
                InsertAllAzureStorageQueuesMessage(queueConnStr, onlineBotList, command, log);

                return onlineBotList.Count;
            } catch (Exception ex)
            {
                log.LogError("[ERROR] " + ex.Message);
                return -1;
            }
        }

        public static async Task<int> ScaleCommandToBots(string numOfBotsStr, string k8sApiUri, string k8sBearerToken,
            string k8sDeploymentName, ILogger log)
        {
            try
            {
                log.LogInformation("[INFO] Attempting to scale to " + numOfBotsStr + " pods.");
                var parsedNumOfBots = int.Parse(numOfBotsStr);
                var kubernetesClient = new KubernetesClient(log);
                await kubernetesClient.Scale(parsedNumOfBots, k8sApiUri, k8sBearerToken, k8sDeploymentName);
  
                return parsedNumOfBots;
            } catch (Exception ex)
            {
                log.LogError("[ERROR] " + ex.Message);
                return -1;
            }
        }

        public static List<string> GetRathenaOnlineChars (string dbConnStr, ILogger log, string startWithFilter="")
        {
            string sqlQuery = "SELECT name FROM `char` WHERE online = 1";
            var conn = new MySqlConnection();
            conn.ConnectionString = dbConnStr;
            var cmd = new MySqlCommand(sqlQuery, conn);
            MySqlDataReader reader;
            List<string> onlineChars = new List<string>();

            if (startWithFilter.Length > 0)
            {
                sqlQuery += " AND name LIKE @startWithFilter";
                cmd.CommandText = sqlQuery;
                cmd.Parameters.AddWithValue("@startWithFilter", startWithFilter + "%");
            }
            try
            {
                log.LogInformation("[INFO]: Opening database connection...");
                conn.Open();
                log.LogInformation("[INFO]: Executing query '" + sqlQuery);
                reader = cmd.ExecuteReader();
                while(reader.Read())
                {
                    onlineChars.Add(reader.GetString("name"));
                }
            }
            catch (Exception ex)
            {
                log.LogError("[ERROR] Database connection error: " + ex.Message);
            } finally
            {
                conn.Close();
            }

            return onlineChars;
        }

        public static async void InsertAllAzureStorageQueuesMessage (string queueConnStr, List<string> queueNames, string message, ILogger log)
        {
            await queueNames.ParallelForEachAsync(async currentQueue =>
            {
                //log.LogInformation("[INFO]: Launched in parallel queue " + currentQueue + ".");
                await InsertAzureStorageQueueMessage(queueConnStr, currentQueue, message, log);
            }, maxDegreeOfParalellism: 100);
        }

        public static async Task InsertAzureStorageQueueMessage (string queueConnStr, string queueName, string message, ILogger log)
        {
            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(queueConnStr);
            CloudQueueClient queueClient = storageAccount.CreateCloudQueueClient();
            CloudQueue queue = queueClient.GetQueueReference(queueName);
            string base64message = Base64Encode(message);
            try
            {
                await queue.AddMessageAsync(new CloudQueueMessage(base64message, true));
                //log.LogInformation("[INFO]: Successful queue insert. Queue => " + queueName + "; Message => " + message + ". Base64: " + base64message);
            } catch (Exception ex)
            {
                log.LogError("[ERROR]: " + ex.Message);
            }
        }

        public static string Base64Encode(string plainText)
        {
            var plainTextBytes = System.Text.Encoding.UTF8.GetBytes(plainText);
            return System.Convert.ToBase64String(plainTextBytes);
        }

        public static string Base64Decode(string base64EncodedData)
        {
            var base64EncodedBytes = System.Convert.FromBase64String(base64EncodedData);
            return System.Text.Encoding.UTF8.GetString(base64EncodedBytes);
        }
    }
}
