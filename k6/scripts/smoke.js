import http from 'k6/http';
import { check } from 'k6';

export const options = {
    vus: 1,
    iterations: 1,
    insecureSkipTLSVerify: true,
};

export default function () {

    const params = {
        headers: {
            "X-API-Key": "my-secret-key",
        },
    };

    const res = http.get(
        'http://traefik/api/person/1001',
        params
    );

    check(res, {
        'status is 200': (r) => r.status === 200,
    });

    console.log(`Status: ${res.status}`);
    console.log(`Response time: ${res.timings.duration} ms`);
}
