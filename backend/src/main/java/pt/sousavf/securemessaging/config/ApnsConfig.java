package pt.sousavf.securemessaging.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import pt.sousavf.securemessaging.service.ApnsPushService;
import pt.sousavf.securemessaging.repository.DeviceTokenRepository;

/*

@Configuration
@EnableAsync
public class ApnsConfig {

    @Bean
    @ConditionalOnProperty(name = "apns.enabled", havingValue = "true")
    public ApnsPushService apnsPushService(DeviceTokenRepository deviceTokenRepository) {
        ApnsPushService service = new ApnsPushService(deviceTokenRepository);
        try {
            service.initializeClient();
        } catch (Exception e) {
            throw new RuntimeException("Failed to initialize APNs service", e);
        }
        return service;
    }
}


*/
