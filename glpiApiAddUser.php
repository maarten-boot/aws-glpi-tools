<?php

require 'php/CommonHttpCurlApi.class.php';
require 'php/GlpiApi.class.php';

function main()
{
    # TODO: should be environment or external confif; later
    $apiUrl = "https://glpi.yourdomain.faraway/apirest.php";
    $userToken = "your usertoken";
    $apiToken = "yout app token";

    ////////////////////////////////////////////////////
    ////////////////////////////////////////////////////

    $entities_id = 0;
    $name =
    $comment =

    // my aws users do not need passwords or details
    $email = null;
    $realname = null;
    $firstname = null;
    $pwd = null;
    // $pwd = sha1($name);

    ////////////////////////////////////////////////////
    ////////////////////////////////////////////////////

    {
        $longopts  = array(
            "name:",     // Required value
            "comment:",     // Required value
        );
        $options = getopt('', $longopts);

        $name = $options['name'];
        if( ! $name ) {
            echo "FATAL: Name is mandatory\n";
            exit(101);
        }

        $comment = $options['comment'];
        if( ! $comment ) {
            echo "FATAL: Name is mandatory\n";
            exit(101);
        }

        // echo "Work: name = {$name}; comment = {$comment}\n";
    }

    $g = new GlpiApi($apiUrl,$userToken, $apiToken);

    $ret = $g -> SessionOpen();
    if ($ret['status'] === false) {
        echo "error: {$ret['message']}";
        exit(101);
    }

    $ret = $g -> ProfileFindDefault();
    if ($ret['status'] === false) {
        echo "error: {$ret['message']}";
        exit(101);
    }
    $profileId = $ret['id'];

    $ret = $g -> UserFind($name);
    if ($ret['status'] === false) {
        echo "error: {$ret['message']}";
        exit(101);
    }
    $userId = $ret['id'];

    if( ! $userId ) {
        $data = [
            'input' => [
                'name'          => $name,
                'password'      => $pwd,
                'realname'      => $realname,
                'firstname'     => $firstname,
                'language'      => 'en_GB',
                'is_active'     => 1,
                'entities_id'   => $entities_id,
                'comment'       => $comment,
                'profiles_id'   => $profileId,
            ],
        ];

        $ret = $g -> UserCreate($data);
        if ($ret['status'] === false) {
            echo "error: {$ret['message']}";
            exit(101);
        }

        $userId = $ret['id'];
        echo "user: {$name} added successfuly as {$userId}\n";
    }

    if($email) {
        $ret = $g -> UserAddEmail($userId,$email,true);
        if ( ! $ret) {
            echo "error for user: {$name} while adding email";
            exit(101);
        }

        $emailId = $ret['id'];
        echo "user: {$name}/{$userId} mail added: {$email}/{$emailId}\n";
    }
}

main();
