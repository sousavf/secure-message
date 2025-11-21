package pt.sousavf.securemessaging.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web configuration for request interceptors and timeout handling
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final QueryTimeoutInterceptor queryTimeoutInterceptor;

    public WebConfig(QueryTimeoutInterceptor queryTimeoutInterceptor) {
        this.queryTimeoutInterceptor = queryTimeoutInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // Register query timeout interceptor to track request execution time
        registry.addInterceptor(queryTimeoutInterceptor)
                .addPathPatterns("/api/**")
                .addPathPatterns("/");
    }
}
