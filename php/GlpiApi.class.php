<?php

class GlpiApi extends CommonHttpCurlApi
{
    protected $apiUrl;
    protected $userToken;
    protected $appToken;
    protected $sessionToken;

    protected function mkHeaders()
    {
        $this -> headers = [
            "Content-Type: application/json",
            "App-Token: {$this -> appToken}",
            "Session-Token: {$this->sessionToken}",
        ];

        return [
            'status' => true,
            'headers' => $this -> headers,
        ];
    }

    public function __construct(
        $apiUrl,
        $userToken,
        $appToken
    ) {
        parent::__construct();

        $this -> appToken = $appToken;
        $this -> userToken = $userToken;
        $this -> apiUrl = $apiUrl;
    }

    public function SessionOpen()
    {
        $ch = curl_init();
        $url = $this -> apiUrl . "/initSession?Content-Type=%20application/json&app_token={$this->appToken}&user_token={$this->userToken}";

        $ret = $this -> curlHttpStart($ch, $url);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        $ret = $this -> curlExecute($ch);
        if ( $ret['status'] == false ) {
            return $ret;
        }
        curl_close($ch);

        $obj = $ret['obj'];
        $this -> sessionToken = $obj['session_token'];
        return $this -> mkHeaders();
    }

    public function UserCreate($data)
    {
        $ch = curl_init();
        $url = $this -> apiUrl . '/User';

        $ret = $this -> curlHttpStart($ch, $url);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        $ret = $this->curlHttpPostInput($ch, $data);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        $ret = $this -> curlHttpPostFinish($ch);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        curl_close($ch);
        $obj = $ret['obj'];

        if (isset($obj[0])) {
            return [
                'status' => false,
                'message' => $obj[1],
            ];
        }

        return [
            'status' => true,
            'message' => $obj['message'],
            'id' => $obj['id'],
        ];
    }

    function UserFind($name)
    {
        $ch = curl_init();
        $name = urlencode($name);
        $url = $this -> apiUrl . "/search/User?criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=^{$name}$&forcedisplay[0]=2";

        $ret = $this -> curlHttpStart($ch, $url);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        $ret = $this -> curlHttpPostFinish($ch);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        curl_close($ch);
        $obj = $ret['obj'];

        $userId = 0;
        if( isset($obj['data'])) {
            $userId = $obj['data']['0']['2'];
        }
        return [
            'status' => true,
            'id' => $userId,
        ];
    }

    function UserAddEmail(
        $user_id,
        $email,
        $default
    ) {
        $ch = curl_init();
        $url = $this -> apiUrl . "/User/{$user_id}/UserEmail/";

        $ret = $this -> curlHttpStart($ch, $url);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        if ($default) {
            $default = 1;
        } else {
            $default = 0;
        }

        $data = [
            'input' => [
                'users_id'      => $user_id,
                'is_default'    => $default,
                'is_dynamic'    => 0,
                'email'         => $email,
            ],
        ];

        $ret = $this -> curlHttpPostInput($ch,$data);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        $ret = $this -> curlHttpPostFinish($ch);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        curl_close($ch);
        $obj = $ret['obj'];

        return [
            'status'    => true,
            'message'   => 'Email added',
            'id'        => $obj['id'],
        ];
    }

    function ProfileFindDefault()
    {
        $ch = curl_init();

        $search = [
            'criteria[0][field]=3',
            'criteria[0][searchtype]=equals',
            "criteria[0][value]=1",
            'forcedisplay[0]=2',
        ];

        $s = implode('&',$search );
        $url = $this -> apiUrl . "/search/Profile?$s";

        $ret = $this -> curlHttpStart($ch, $url);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        $ret = $this -> curlHttpPostFinish($ch);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        curl_close($ch);
        $obj = $ret['obj'];

        $profileId = 0;
        if( isset($obj['data'])) {
            $profileId = $obj['data']['0']['2'];
        }

        return [
            'status'    => true,
            'id'        => $profileId,
        ];
    }
}
