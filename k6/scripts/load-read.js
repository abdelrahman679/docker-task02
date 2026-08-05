import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    vus: 25,
    duration: '1m',
    insecureSkipTLSVerify: true,
};

const params = {
    headers: {
        "X-API-Key": "my-secret-key",
    },
};

export default function () {

    const res = http.get(
        "http://traefik/api/person/1002",
        params
    );

    check(res, {
        "status is 200": (r) => r.status === 200,
    });

    sleep(1);
}
