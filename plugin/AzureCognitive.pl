package azureCognitive;

use strict;
use Plugins;
use Actor;
use Log qw(message);
use Digest::SHA qw(hmac_sha256_hex);
use REST::Client;
use lib $Plugins::current_plugin_folder;
use Azure::StorageQueue;

my %azureStorageQueue = (
    'AccountName' => $ENV{'STORAGE_ACCOUNT_NAME'},
    'QueueName'   => $ENV{'STORAGE_QUEUE_NAME'},
    'ApiVersion'  => '2018-03-28',
    'AccountKey'  => $ENV{'STORAGE_ACCOUNT_KEY'},
);
my $lastStorageQueueCallEpoch = time();

my $client = REST::Client->new();
Plugins::register("azurecognitive", "Azure Cognitive Plugin", \&on_unload, \&on_reload);
my $hooks = Plugins::addHooks(
    ['packet_pubMsg', \&inbound_pubMsg],
    ['mainLoop_post', \&AI_post],
);

sub on_unload {
    message("\nAzure Cognitive Plugin is unloading...\n\n");
	Plugins::delHooks($hooks);
    undef $hooks;
}

sub on_reload {
	&on_unload;
}

sub AI_post {
    if ((time() - $lastStorageQueueCallEpoch) > 0) {
        my @messagesArray = Azure::StorageQueue::Get_AzureStorageQueueMessages(\%azureStorageQueue, $client, 1, 0);
        if (scalar @messagesArray > 0)
        {
            foreach (@messagesArray) {
                my %message = %$_;
                message("[azurecognitive] Running command $message{'MessageText'}\n");
                Commands::run($message{'MessageText'});
                my $deleteResult = Azure::StorageQueue::Delete_AzureStorageQueueMessage(\%azureStorageQueue, $client, $message{'MessageId'}, $message{'PopReceipt'});
                if ($deleteResult) {
                    message("[azurecognitive] Message $message{'PopReceipt'} WAS NOT deleted\nResponse message: $deleteResult\n");
                } else {
                    message("[azurecognitive] Message $message{'PopReceipt'} was successfully deleted\n");
                }
            }
        } else {
            message(".");
        }
    }
    $lastStorageQueueCallEpoch = time();
}

sub inbound_pubMsg {
    my (undef, $args) = @_;
	my $charname;
    my $chatmsg;
	my $actor;
    my $laclient = REST::Client->new();
    my $reporterName = $ENV{'STORAGE_QUEUE_NAME'};
    my $postJson;
    my $rnd;

    message("[azureCognitive] inbound_pubMsg was successfully called\n");
	if (defined $args->{pubMsgUser}) {
        $charname = $args->{pubMsgUser};
        $chatmsg = $args->{Msg};
		$actor = Actor::get($args->{pubID});
		if ($actor->{guild}{name} ne '') { return; }
	}

    if(index($charname, 'botijo') < 0 ) {
        $rnd = rand();
        message("[azureCognitive] I have heard a chat message from $chatmsg. Random is $rnd\n");
        if ($rnd > 0.9)
        {
            message('[azureCognitive] Randomness decided to go for processing!');
            $laclient->setHost("https://prod-59.westeurope.logic.azure.com");
            $laclient->addHeader('Content-Type', 'application/json');
            $laclient->setTimeout(10);
            $postJson="{ \"reporterName\": \"$reporterName\", \"playerName\": \"$charname\", \"text\": \"$chatmsg\" }";
            $laclient->request('POST', '/workflows/[REPLACE WITH YOUR WORKFLOW ID]/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=[REPLACE WITH YOUR SIGNATURE]', $postJson);

            if($laclient->responseCode() eq '201') {
                Commands::run("c Ey $charname, he enviado a Azure Cognitive lo que has dicho para que sea analizado");
                sleep 2;
                my $sentiment = $laclient->responseContent();
                Commands::run("c Tus palabras denotan un coeficiente de felicidad de $sentiment");
                sleep 2;
                if ($sentiment < 0.3) {
                    Commands::run("c Parece que estas enfadado");
                    sleep 2;
                    Commands::run("e lv");
                    Commands::run("e lv");
                    sleep 2;
                    Commands::run("c No me voy a despegar de ti hasta que sonrias");
                    sleep 2;
                    Commands::run("e lv");
                    Commands::run("follow $charname");
                } else {
                    if ($sentiment >= 0.3 && $sentiment < 0.7) {
                        Commands::run("c Parece que estas ni fu ni fa");
                        sleep 2;
                        Commands::run("e hmm");
                    } else {
                        Commands::run("c Parece que estas muy contento");
                        sleep 2;
                        Commands::run("e 21");
                        sleep 2;
                        Commands::run("c Hakunamatata Hulio");
                        Commands::run("e no1");
                        Commands::run("follow stop");
                    }
                }
            } else {
                Commands::run("c Humm... $charname, he intentado enviar lo que has comentado a Azure Cognitive...");
                sleep 2;
                Commands::run("c pero no se Rick, parece que no funciona");
                sleep 2;
                Commands::run("c " . $laclient->responseCode());
                Commands::run("c " . $laclient->responseContent());
            }
        }
    }
}

1;