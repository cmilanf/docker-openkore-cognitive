#!/usr/bin/perl
###############################################################################
# PROGRAM       : Azure Storage Queue API plugin for Perl
# DESCRIPTION   : Provides easy abstraction routines to work with commom
#                 Azure Storage Queues with Shared Key auth method.
# DATE          : 10/03/2019
# AUTHOR        : Carlos Milán Figueredo
# LICENSE       : MIT License
###############################################################################
# Copyright 2019 Carlos Milán Figueredo
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
###############################################################################
# ======== XML formal of Azure Storage Queue messages =======
# <?xml version="1.0" encoding="utf-8"?>
# <QueueMessagesList>
#     <QueueMessage>
#         <MessageId>91044a4d-5355-404a-9fac-e3d1991c0305</MessageId>
#         <InsertionTime>Sun, 10 Mar 2019 10:33:52 GMT</InsertionTime>
#         <ExpirationTime>Sun, 17 Mar 2019 10:33:52 GMT</ExpirationTime>
#         <PopReceipt>AgAAAAMAAAAAAAAAJXtUwSzX1AE=</PopReceipt>
#         <TimeNextVisible>Sun, 10 Mar 2019 10:33:52 GMT</TimeNextVisible>
#     </QueueMessage>
# </QueueMessagesList>
###############################################################################
# Subroutines expect the following hash reference with Storage Account data:
# my %azureStorageQueue = (
#    'AccountName' => $ENV{'STORAGE_ACCOUNT_NAME'},
#    'QueueName'   => $ENV{'STORAGE_QUEUE_NAME'},
#    'ApiVersion'  => '2018-03-28',
#    'AccountKey'  => $ENV{'STORAGE_ACCOUNT_KEY'},
#);
###############################################################################
# Subroutes expect a externally created REST::Client
###############################################################################
package Azure::StorageQueue;

use strict;
use REST::Client;
use Digest::SHA qw(hmac_sha256);
use Time::Piece;
use MIME::Base64;
use XML::LibXML;
use Data::Dumper;

#Test_PutMessagesInQueue($client, "c Prueba", 10);
#Test_GetMessagesInQueue($client, 10, 10);

sub Test_PutMessagesInQueue {
    my $storageAccountRef = shift;
    my $client = shift;
    my $message = shift;
    my $num_messages = shift;

    for (my $i=0; $i < $num_messages; $i++) {
        if(Put_AzureStorageQueueMessage($storageAccountRef, $client, "$message $i")) {
            print "$i: FAILED POST message '$message $i'\n";
        } else {
            print "$i: POST of message '$message'\n";
        }
    }
}

sub Test_GetMessagesInQueue {
    my $storageAccountRef = shift;
    my $client = shift;
    my $numofrequests = shift // 1;
    my $numofmessages = shift // 1;
    my @messages;

    for (my $i=0; $i <= $numofrequests; $i++) {
        @messages = Get_AzureStorageQueueMessages($storageAccountRef, $client, $numofmessages, 1);
        print "$i: Got a message\n";
        foreach(@messages) {
            print Dumper(\$_);
        }
    }
}

sub Get_AzureSignatureTime {
    my $t = gmtime(time);
    my $strftime = $t->strftime();
    $strftime =~ s/UTC/GMT/g;

    return $strftime;
}

sub Get_AzureAuthorizationSignature {
    my $storageAccountRef = shift;
    my $verb = shift // 'GET';
    my $strftime = shift;
    my $resource = shift // 'messages';

    my $canonicalizedHeaders = "x-ms-date:$strftime\nx-ms-version:$storageAccountRef->{'ApiVersion'}";
    my $canonicalizedResources = "/$storageAccountRef->{'AccountName'}/$storageAccountRef->{'QueueName'}/$resource";
    my $signatureString = "$verb\n\n\n\n$canonicalizedHeaders\n$canonicalizedResources";
    my $signature = encode_base64(hmac_sha256($signatureString, decode_base64($storageAccountRef->{'AccountKey'})));

    return $signature;
}

sub Set_AzureStorageRestHeaders {
    my $storageAccountRef = shift;
    my $client = shift;
    my $verb = shift;
    my $resource = shift;
    my $strftime = Get_AzureSignatureTime();
    my $signature = Get_AzureAuthorizationSignature($storageAccountRef, $verb, $strftime, $resource);

    $client->setHost("https://$storageAccountRef->{'AccountName'}.queue.core.windows.net");
    $client->addHeader('x-ms-date', $strftime);
    $client->addHeader('x-ms-version', $storageAccountRef->{'ApiVersion'});
    $client->addHeader('Authorization', "SharedKeyLite $storageAccountRef->{'AccountName'}:$signature");
    $client->setTimeout(10);

    return $client;
}

sub Get_AzureStorageQueueMessages {
    my $storageAccountRef = shift;
    my $client = shift;
    my $numofmessages = shift // 1;
    my $peekonly = shift // 0;
    my $dom;
    my $queueMessage;
    my %message = (
        'ExpirationTime' => '',
        'TimeNextVisible' => '',
        'DequeueCount' => '',
        'MessageText' => '',
        'MessageId' => '',
        'InsertionTime' => '',
        'PopReceipt' => '',
    );
    my @messagesArray;

    if ($numofmessages > 32) { $numofmessages = 32; }
    Set_AzureStorageRestHeaders($storageAccountRef, $client, 'GET');
    if($peekonly) {
        $client->request('GET', "/$storageAccountRef->{'QueueName'}/messages?numofmessages=$numofmessages&peekonly=true");
    } else {
        $client->request('GET', "/$storageAccountRef->{'QueueName'}/messages?numofmessages=$numofmessages");
    }
    if($client->responseCode() eq '200'){
        $dom = XML::LibXML->load_xml(string => $client->responseContent());
        foreach $queueMessage ($dom->findnodes('//QueueMessage')) {
            $message{'ExpirationTime'}=$queueMessage->findvalue('./ExpirationTime');
            $message{'TimeNextVisible'}=$queueMessage->findvalue('./TimeNextVisible');
            $message{'DequeueCount'}=$queueMessage->findvalue('./DequeueCount');
            $message{'MessageText'}=decode_base64($queueMessage->findvalue('./MessageText'));
            $message{'MessageId'}=$queueMessage->findvalue('./MessageId');
            $message{'InsertionTime'}=$queueMessage->findvalue('./InsertionTime');
            $message{'PopReceipt'}=$queueMessage->findvalue('./PopReceipt');
            push (@messagesArray, \%message);
        }
    }
    return @messagesArray;
}

sub Clear_AzureStorageQueueMessages {
    my $storageAccountRef = shift;
    my $client = shift;
    my $popReceipt = shift;

    Set_AzureStorageRestHeaders($storageAccountRef, $client, 'DELETE');
    $client->request('DELETE', "/$storageAccountRef->{'QueueName'}/messages");
    if ($client->responseCode() eq '204') {
        return 0;
    } else {
        return $client->responseContent();
    }
}

sub Delete_AzureStorageQueueMessage {
    my $storageAccountRef = shift;
    my $client = shift;
    my $messageId = shift;
    my $popReceipt = shift;

    Set_AzureStorageRestHeaders($storageAccountRef, $client, 'DELETE', "messages/$messageId");
    $client->request('DELETE', "/$storageAccountRef->{'QueueName'}/messages/$messageId?popreceipt=$popReceipt");
    if ($client->responseCode() eq '204') {
        return 0;
    } else {
        return $client->responseContent();
    }
}

sub Put_AzureStorageQueueMessage {
    my $storageAccountRef = shift;
    my $client = shift;
    my $messageContent = shift;
    my $base64messageContent = encode_base64($messageContent);
    my $queueMessage = "<QueueMessage>\n\t<MessageText>$base64messageContent</MessageText>\n</QueueMessage>";

    Set_AzureStorageRestHeaders($storageAccountRef, $client, 'POST');
    $client->request('POST', "/$storageAccountRef->{'QueueName'}/messages", $queueMessage);
    if($client->responseCode() eq '201') {
        return 0;
    } else {
        return $client->responseContent();
    }
}

1;