// K6 Load Test for Odoo
import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },  // Ramp-up to 10 users
    { duration: '5m', target: 10 },  // Stay at 10 users
    { duration: '2m', target: 50 },  // Ramp-up to 50 users
    { duration: '5m', target: 50 },  // Stay at 50 users
    { duration: '2m', target: 0 },   // Ramp-down to 0 users
  ],
  thresholds: {
    'http_req_duration': ['p(95)<2000'], // 95% of requests should be below 2s
    'errors': ['rate<0.1'],              // Error rate should be below 10%
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://odoo-stage.local';

// Setup - runs once
export function setup() {
  // You can perform login here and return session data
  return {};
}

// Main test scenario
export default function(data) {
  group('Homepage', function() {
    let res = http.get(`${BASE_URL}/`);

    check(res, {
      'status is 200': (r) => r.status === 200,
      'page contains Odoo': (r) => r.body.includes('Odoo'),
    }) || errorRate.add(1);

    sleep(1);
  });

  group('Web Client', function() {
    let res = http.get(`${BASE_URL}/web`);

    check(res, {
      'status is 200': (r) => r.status === 200,
      'response time < 2s': (r) => r.timings.duration < 2000,
    }) || errorRate.add(1);

    sleep(2);
  });

  group('Database List', function() {
    let res = http.get(`${BASE_URL}/web/database/selector`);

    check(res, {
      'status is 200 or 303': (r) => r.status === 200 || r.status === 303,
    }) || errorRate.add(1);

    sleep(1);
  });

  group('Health Check', function() {
    let res = http.get(`${BASE_URL}/web/health`);

    check(res, {
      'status is 200': (r) => r.status === 200,
      'response time < 500ms': (r) => r.timings.duration < 500,
    }) || errorRate.add(1);
  });
}

// Teardown - runs once
export function teardown(data) {
  // Cleanup if needed
}
