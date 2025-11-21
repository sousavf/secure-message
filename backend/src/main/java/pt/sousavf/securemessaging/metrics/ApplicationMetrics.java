package pt.sousavf.securemessaging.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Component;

/**
 * Custom application metrics for monitoring key operations
 * Metrics are exposed via /actuator/prometheus endpoint
 */
@Component
public class ApplicationMetrics {

    private final Counter messageCreatedCounter;
    private final Counter messageRetrievedCounter;
    private final Counter conversationCreatedCounter;
    private final Counter conversationDeletedCounter;
    private final Counter pushNotificationSentCounter;
    private final Counter pushNotificationFailedCounter;
    private final Timer messageRetrievalTimer;
    private final Timer conversationCreationTimer;

    public ApplicationMetrics(MeterRegistry meterRegistry) {
        // Message metrics
        this.messageCreatedCounter = Counter.builder("app.messages.created")
                .description("Total number of messages created")
                .register(meterRegistry);

        this.messageRetrievedCounter = Counter.builder("app.messages.retrieved")
                .description("Total number of messages retrieved")
                .register(meterRegistry);

        // Conversation metrics
        this.conversationCreatedCounter = Counter.builder("app.conversations.created")
                .description("Total number of conversations created")
                .register(meterRegistry);

        this.conversationDeletedCounter = Counter.builder("app.conversations.deleted")
                .description("Total number of conversations deleted")
                .register(meterRegistry);

        // Push notification metrics
        this.pushNotificationSentCounter = Counter.builder("app.push_notifications.sent")
                .description("Total number of push notifications sent")
                .register(meterRegistry);

        this.pushNotificationFailedCounter = Counter.builder("app.push_notifications.failed")
                .description("Total number of push notifications failed")
                .register(meterRegistry);

        // Timing metrics
        this.messageRetrievalTimer = Timer.builder("app.message.retrieval.time")
                .description("Time taken to retrieve messages")
                .register(meterRegistry);

        this.conversationCreationTimer = Timer.builder("app.conversation.creation.time")
                .description("Time taken to create a conversation")
                .register(meterRegistry);
    }

    public void recordMessageCreated() {
        messageCreatedCounter.increment();
    }

    public void recordMessageRetrieved() {
        messageRetrievedCounter.increment();
    }

    public void recordConversationCreated() {
        conversationCreatedCounter.increment();
    }

    public void recordConversationDeleted() {
        conversationDeletedCounter.increment();
    }

    public void recordPushNotificationSent() {
        pushNotificationSentCounter.increment();
    }

    public void recordPushNotificationFailed() {
        pushNotificationFailedCounter.increment();
    }

    public Timer.Sample startMessageRetrievalTimer() {
        return Timer.start();
    }

    public void stopMessageRetrievalTimer(Timer.Sample sample) {
        sample.stop(messageRetrievalTimer);
    }

    public Timer.Sample startConversationCreationTimer() {
        return Timer.start();
    }

    public void stopConversationCreationTimer(Timer.Sample sample) {
        sample.stop(conversationCreationTimer);
    }
}
