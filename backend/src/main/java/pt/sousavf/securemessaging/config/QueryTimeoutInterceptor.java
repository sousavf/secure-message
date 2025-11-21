package pt.sousavf.securemessaging.config;

import org.springframework.web.servlet.HandlerInterceptor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Interceptor to track query execution time and log slow queries
 * Helps identify performance bottlenecks in production
 */
public class QueryTimeoutInterceptor implements HandlerInterceptor {

    private static final Logger logger = LoggerFactory.getLogger(QueryTimeoutInterceptor.class);
    private static final long SLOW_QUERY_THRESHOLD_MS = 1000; // 1 second

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {
        // Store request start time
        request.setAttribute("startTime", System.currentTimeMillis());
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler,
            Exception ex) throws Exception {
        long startTime = (long) request.getAttribute("startTime");
        long duration = System.currentTimeMillis() - startTime;

        if (duration > SLOW_QUERY_THRESHOLD_MS) {
            logger.warn(
                    "Slow request detected: {} {} completed in {}ms - Response Status: {}",
                    request.getMethod(),
                    request.getRequestURI(),
                    duration,
                    response.getStatus()
            );
        } else if (logger.isDebugEnabled()) {
            logger.debug(
                    "Request: {} {} completed in {}ms",
                    request.getMethod(),
                    request.getRequestURI(),
                    duration
            );
        }
    }
}
