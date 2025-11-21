package pt.sousavf.securemessaging.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Database configuration for query timeout and performance optimization
 *
 * HikariCP connection pool and PostgreSQL statement timeout are configured via application.yml:
 * - spring.datasource.hikari.* - Connection pool settings
 * - spring.jpa.properties.hibernate.jdbc.* - Batch and fetch size optimization
 *
 * Additional timeout protection is provided by:
 * - server.tomcat.connection-timeout - Request connection timeout
 * - server.tomcat.keep-alive-timeout - HTTP keep-alive timeout
 */
@Configuration
public class DatabaseConfig {

    private static final Logger logger = LoggerFactory.getLogger(DatabaseConfig.class);

    @Bean
    public QueryTimeoutInterceptor queryTimeoutInterceptor() {
        logger.info("Initializing QueryTimeoutInterceptor for request tracking and slow query detection");
        return new QueryTimeoutInterceptor();
    }
}
