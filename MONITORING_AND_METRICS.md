# Monitoring and Metrics Setup

## Overview

Safe Whisper backend is now equipped with comprehensive monitoring capabilities to support scaling from 10K to 1M concurrent users. All metrics are exposed via the Prometheus endpoint.

## Accessing Metrics

### Prometheus Endpoint
```
GET http://localhost:8687/actuator/prometheus
```

### Health Endpoint
```
GET http://localhost:8687/actuator/health
```

### Health Details (with all components)
```
GET http://localhost:8687/actuator/health/details
```

## Available Metrics

### Custom Application Metrics

#### Message Metrics
- `app_messages_created` - Counter of total messages created
- `app_messages_retrieved` - Counter of total messages retrieved
- `app_message_retrieval_time` - Timer tracking message retrieval performance (p50, p95, p99)

#### Conversation Metrics
- `app_conversations_created` - Counter of total conversations created
- `app_conversations_deleted` - Counter of total conversations deleted
- `app_conversation_creation_time` - Timer tracking conversation creation performance

#### Push Notification Metrics
- `app_push_notifications_sent` - Counter of push notifications sent
- `app_push_notifications_failed` - Counter of failed push notifications

### JVM Metrics (Automatically Collected)
- `jvm_memory_used` - Current JVM memory usage
- `jvm_memory_max` - Max JVM memory
- `jvm_threads_live` - Number of live threads
- `jvm_gc_memory_allocated` - Garbage collection memory allocated
- `jvm_gc_pause` - Garbage collection pause time

### Tomcat Metrics (Automatically Collected)
- `tomcat_sessions_active` - Number of active HTTP sessions
- `tomcat_threads_busy` - Number of busy Tomcat threads
- `tomcat_threads_current` - Current Tomcat thread count
- `tomcat_global_request` - Total HTTP requests
- `tomcat_global_error` - Total HTTP errors

### HTTP Metrics (Automatically Collected)
- `http_requests_total` - Total HTTP requests by method and status
- `http_requests_duration` - Request duration in seconds

## Monitoring Setup with Prometheus + Grafana

### 1. Install Prometheus

Create `prometheus.yml`:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'secure-messaging'
    static_configs:
      - targets: ['localhost:8687']
    metrics_path: '/actuator/prometheus'
```

### 2. Install Grafana

1. Download and run Grafana
2. Access http://localhost:3000 (default: admin/admin)
3. Add Prometheus data source: http://localhost:9090

### 3. Create Grafana Dashboard

Key metrics to track:

**Request Performance**
- P50/P95/P99 latency for message retrieval
- Request throughput (requests/second)
- HTTP error rate

**Database Performance**
- Active database connections
- Query execution time
- Slow query count

**Application Health**
- Message creation rate
- Conversation creation rate
- Push notification delivery rate
- Push notification failure rate

**JVM Health**
- Heap memory usage
- Garbage collection frequency and pause time
- Thread count

## Slow Query Detection

The `QueryTimeoutInterceptor` automatically logs requests that take longer than 1000ms:

```
WARN: Slow request detected: GET /api/conversations/{id}/messages completed in 1500ms - Response Status: 200
```

These logs help identify performance bottlenecks that need optimization.

## Connection Pool Monitoring

HikariCP connection pool is configured with:
- **Maximum pool size**: 20 connections
- **Minimum idle**: 5 connections
- **Connection timeout**: 30 seconds
- **Idle timeout**: 10 minutes
- **Max lifetime**: 30 minutes

Monitor these metrics:
- `hikaricp_connections` - Current connection count
- `hikaricp_connections_idle` - Idle connections
- `hikaricp_connections_active` - Active connections
- `hikaricp_connections_pending` - Pending connection requests

## Statement Timeout

PostgreSQL statement timeout is configured with:
- **Default timeout**: 60 seconds (for most queries)
- **API request timeout**: 30 seconds

If a query exceeds the timeout, it's automatically cancelled:
```sql
-- Set per-connection timeout
SET statement_timeout = 60000;  -- 60 seconds in milliseconds
```

## Request Timeout Configuration

Tomcat request handling timeouts:
- **Connection timeout**: 60 seconds
- **Keep-alive timeout**: 60 seconds
- **Max threads**: 200 request processing threads
- **Min spare threads**: 10 idle threads

## Recommended Monitoring Alerts

### Critical Alerts (Page on-call)
1. Error rate > 1% for 5 minutes
2. Request latency p99 > 10 seconds for 5 minutes
3. Database connection pool exhausted
4. JVM heap memory > 85% for 10 minutes
5. Push notification failure rate > 5% for 10 minutes

### Warning Alerts (Notify team)
1. Request latency p95 > 2 seconds for 10 minutes
2. Slow queries detected (> 1 second) in last hour
3. Active database connections > 15
4. JVM heap memory > 75% for 5 minutes
5. Garbage collection pause time > 1 second

### Info Alerts (Log for analysis)
1. Message creation rate > 1000/minute
2. Conversation deletion rate > 100/minute
3. Memory leak detection (heap growth over 1 hour)

## Performance Baselines

These are baseline metrics for scaling planning:

### Single Instance (Local Development)
- Throughput: 100-500 requests/second
- Message retrieval p50: 50-100ms
- Message retrieval p99: 500-1000ms
- Connection pool utilization: 10-30%
- GC pause time: 10-50ms

### Production Setup (1M Concurrent Users)
- Throughput: 10,000-50,000 requests/second
- Message retrieval p50: 50-100ms
- Message retrieval p99: 200-500ms (with pagination & indexes)
- Database connection pool utilization: 80-90%
- GC pause time: 100-300ms (with proper tuning)

## Scaling Indicators

**Scale Up When:**
1. Error rate increases above 0.1%
2. Request latency p99 > 1 second
3. Database connections > 15 (of 20)
4. JVM heap > 80%
5. CPU usage > 75%

**Optimize Before Scaling:**
1. Check slow query logs
2. Review query execution plans
3. Verify indexes are being used
4. Check for N+1 query problems
5. Profile garbage collection

## Metrics Endpoint Response Example

```json
{
  "jvm_memory_used_bytes": 234567890,
  "jvm_memory_max_bytes": 1073741824,
  "app_messages_created_total": 45678,
  "app_messages_retrieved_total": 123456,
  "app_message_retrieval_time_seconds_count": 98765,
  "app_message_retrieval_time_seconds_sum": 2345.67,
  "app_message_retrieval_time_seconds_max": 5.234,
  "http_requests_total": 234567,
  "http_requests_duration_seconds_sum": 12345.67,
  "tomcat_global_request_max": 150,
  "tomcat_threads_config_max": 200,
  "tomcat_threads_current": 85
}
```

## Key Files

- **Config**: `/backend/src/main/resources/application.yml`
- **Metrics**: `/backend/src/main/java/pt/sousavf/securemessaging/metrics/ApplicationMetrics.java`
- **Aspect**: `/backend/src/main/java/pt/sousavf/securemessaging/metrics/MetricsAspect.java`
- **Interceptor**: `/backend/src/main/java/pt/sousavf/securemessaging/config/QueryTimeoutInterceptor.java`

## Next Steps for Production

1. **Set up Prometheus scraping** with appropriate intervals (15-30 seconds)
2. **Configure Grafana dashboards** for real-time monitoring
3. **Set up alerting** using AlertManager
4. **Enable log aggregation** (ELK stack or similar)
5. **Set up distributed tracing** (optional: Jaeger/Zipkin for request tracing)
6. **Configure auto-scaling** based on CPU and memory metrics
7. **Implement SLA monitoring** (track p95/p99 latency targets)

## Troubleshooting

### Metrics Not Showing
1. Verify `/actuator/prometheus` endpoint is accessible
2. Check Spring Boot Actuator is enabled in application.yml
3. Ensure micrometer-registry-prometheus dependency is present

### High Latency Alerts
1. Check slow query logs in QueryTimeoutInterceptor output
2. Verify database indexes are being used (EXPLAIN ANALYZE)
3. Check JVM garbage collection patterns
4. Review active database connections

### Memory Leaks
1. Monitor JVM heap memory trend over time
2. Take heap dumps when memory doesn't decrease after GC
3. Analyze heap dumps for object accumulation
4. Check for unclosed database connections or streams

### Connection Pool Exhaustion
1. Scale up maximum pool size (currently 20)
2. Check for long-running queries tying up connections
3. Ensure connections are being properly released
4. Enable connection pool monitoring logs
