<?php

class CommonHttpCurlApi {
    protected $headers;

    public function __construct() {

    }

    protected function curlHttpStart($ch, $url) {
        if ( ! $ch) {
            return [
                'status'    => false,
                'message'   => 'Curl Error: ' . curl_error($ch),
            ];
        }

        if (false == curl_setopt(
                $ch,
                CURLOPT_URL,
                $url
            )
        ) {
            return [
                'status'    => false,
                'message'   => 'Curl Error: ' . curl_error($ch),
            ];
        }

        if (false == curl_setopt(
                $ch,
                CURLOPT_RETURNTRANSFER,
                true
            )
        ) {
            return [
                'status'    => false,
                'message'   => 'Curl Error: ' . curl_error($ch),
            ];
        }

        if (false == curl_setopt(
                $ch,
                CURLOPT_SSL_VERIFYPEER,
                false
            )
        ) {
            return [
                'status'    => false,
                'message'   => 'Curl Error: ' . curl_error($ch),
            ];
        }

        return [
            'status' => true,
        ];
    }

    protected function curlExecute($ch)
    {
        $json = curl_exec($ch);
        if ( ! $json) {
            return [
                'status'    => false,
                'message'   => 'Curl Error: ' . curl_error($ch),
            ];
        }

        $obj = json_decode(
            $json,
            true
        );
        if ( ! $obj) {
            return [
                'status'    => false,
                'message'   => "Json Error: $json" . json_last_error_msg(),
            ];
        }

        return [
            'status'    => true,
            'obj'       => $obj,
        ];
    }

    protected function curlHttpPostFinish($ch)
    {
        if (false == curl_setopt($ch,CURLOPT_HTTPHEADER,$this -> headers)) {
            return [
                'status'    => false,
                'message'   => 'Curl Error: ' . curl_error($ch),
            ];
        }

        if (false == curl_setopt(
                $ch,
                CURLOPT_CUSTOMREQUEST,
                'POST'
            )
        ) {
            return [
                'status'    => false,
                'message'   => 'Curl Error: ' . curl_error($ch),
            ];
        }

        $ret = $this -> curlExecute($ch);
        if ( $ret['status'] == false ) {
            return $ret;
        }

        return [
            'status'    => true,
            'obj'       => $ret['obj'],
        ];
    }

    protected function curlHttpPostInput($ch, $data)
    {
        $input = json_encode($data);
        if ( ! $input) {
            return [
                'status'    => false,
                'message'   => "Json Error: $input" . json_last_error_msg(),

            ];
        }

        if (false == curl_setopt(
                $ch,
                CURLOPT_POSTFIELDS,
                $input
            )
        ) {
            return [
                'status'    => false,
                'message'   => 'Curl Error: ' . curl_error($ch),
            ];
        }

        return [
            'status' => true,
        ];
    }

}
