#!/usr/bin/env python3
"""
Locust load testing file for Odoo
"""
from locust import HttpUser, task, between, events
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class OdooUser(HttpUser):
    """Simulates a user interacting with Odoo"""

    wait_time = between(1, 3)  # Wait 1-3 seconds between tasks

    def on_start(self):
        """Called when a simulated user starts"""
        logger.info("User started")
        # You can perform login here if needed
        # self.login()

    def login(self):
        """Login to Odoo (if authentication is enabled)"""
        response = self.client.post("/web/login", {
            "login": "admin",
            "password": "admin",
            "csrf_token": self.get_csrf_token()
        })

        if response.status_code == 200:
            logger.info("Login successful")
        else:
            logger.error(f"Login failed: {response.status_code}")

    def get_csrf_token(self):
        """Get CSRF token from the login page"""
        response = self.client.get("/web/login")
        # Extract CSRF token from response (implementation depends on Odoo version)
        return ""

    @task(3)
    def view_homepage(self):
        """Access the homepage"""
        with self.client.get("/", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(5)
    def view_web_client(self):
        """Access the web client"""
        with self.client.get("/web", catch_response=True) as response:
            if response.status_code in [200, 303]:
                response.success()
            else:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(2)
    def check_health(self):
        """Check application health endpoint"""
        with self.client.get("/web/health", catch_response=True) as response:
            if response.status_code == 200:
                if response.elapsed.total_seconds() < 0.5:
                    response.success()
                else:
                    response.failure("Health check took too long")
            else:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def view_database_selector(self):
        """Access database selector"""
        with self.client.get("/web/database/selector", catch_response=True) as response:
            if response.status_code in [200, 303]:
                response.success()
            else:
                response.failure(f"Failed with status code: {response.status_code}")

    @task(1)
    def api_version(self):
        """Check API version endpoint"""
        with self.client.get("/web/webclient/version_info", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Failed with status code: {response.status_code}")


class OdooAdminUser(HttpUser):
    """Simulates an admin user with heavier operations"""

    wait_time = between(2, 5)
    weight = 1  # Fewer admin users compared to regular users

    @task(1)
    def view_settings(self):
        """Access settings (requires authentication)"""
        self.client.get("/web#menu_id=X&action=base.action_res_users")

    @task(1)
    def view_apps(self):
        """Browse available apps"""
        self.client.get("/web#menu_id=X&action=base.open_module_tree")


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the test starts"""
    logger.info("Load test starting...")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the test stops"""
    logger.info("Load test completed!")
    logger.info(f"Total requests: {environment.stats.total.num_requests}")
    logger.info(f"Total failures: {environment.stats.total.num_failures}")
    logger.info(f"Average response time: {environment.stats.total.avg_response_time:.2f}ms")
    logger.info(f"Requests per second: {environment.stats.total.total_rps:.2f}")
