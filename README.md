# OpenKore integration Amazon Alexa and Azure Cognitive Services - Amazon Alexa integration with Kubernetes API
[OpenKore](https://github.com/OpenKore/openkore) is a free/open source client and automation tool for Ragnarok Online. This dockerized version is very similar to the one I published [here](https://github.com/cmilanf/docker-openkore), but has been extended to perform several experiments with Amazon Alexa, Azure Cognitive Services and Kubernetes with success:

These files were used by [Alberto Marcos](https://twitter.com/alber86) and myself in our session at [Global Azure Bootcamp 2019 - Madrid, Spain](https://azurebootcamp.es/) that you can watch entirely here (sorry, Spanish language only):

[![GAB 2019 - Track 1 - MMORPG SOBRE AKS Y LA REBELIÓN DE LOS BOTS COGNITIVOS](https://img.youtube.com/vi/Ovi7L6GdLQI/0.jpg)](https://www.youtube.com/watch?v=Ovi7L6GdLQI)

In the project, the following items were developed:

  * **OpenKore plugin**. Polls an Azure Storage Queue and executes the commands that are found there.
  * **Amazon Alexa skill**. Allows us to issue voice commands to OpenKore and the Kubernetes cluster.
  * **Azure Function**. Collects the voice commands from Alexa and issues them to the Azure Storage Queue and the Kubernetes API.
  * **Azure Congitive Services**. Some OpenKore bots will use Text Analytics to get the sentiment of what people is talking inside the game and make the bot offer assistance if needed.
  * **Azure Logic App**. It will recieve the in-game conversations in the bot range, forward them to TextAnalyics and return via HTTP response the analysis result.

## File and directory description

  * **config/**. Custom automation config depending on character class.
  * **k8s/**. Kubernetes YAML files to deploy the service in AKS.
  * **azure/**. Azure Functions Visual Studio project for DotNetCore 2.1. It recieves Alexa voice commands and then issue the proper calls to Azure Storage Queue and Kubernetes APIs.
  * **azure/AlexaOpenKoreAzFunc/alexaskill.json**. Alexa skill used for this project.
  * **plugin/**. The OpenKore plugin that perform two actions: poll the Azure Storage Queue and send conversations to Azure Cognitive Services.
  * **plugin/Azure/loginapp_sentiment.json**. The Azure Logic App JSON that recieves the in-game chat, forwards to Azure Cognitive Services and send it back to the OpenKore plugin via HTTP response.
  * **Dockerfile**. Docker image definition for this project.
  * **docker-entrypoint.sh**. The Docker entrypoint that leaves the container in the desired state for execution.
  * **recvpackets.txt**. Sample results from [this process](http://openkore.com/index.php/Packet_Length_Extractor), needed if we are connecting OpenKore to rAthena.
  * **servers.txt**. Server configuration for rAthena, values explanation can be found [here](http://openkore.com/index.php/Connectivity_Guide)

## Warning!

This repository is about an experiment and we didn't care a single bit about good practices or security.

## Related projects:

  * [docker-openkore](https://github.com/cmilanf/docker-openkore)
  * [azure-perl](https://github.com/cmilanf/azure-perl)

## Thanks

  * Álvaro Marcos for his support when developing the Kubernetes API access from Azure Functions.
  * Beatriz Sebastián Peña, for her SQL tips.

## License
MIT License

Copyright (c) 2019 Carlos Milán Figueredo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.