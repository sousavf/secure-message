package pt.sousavf.securemessaging.metrics;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Aspect to automatically measure method execution times
 * Can be used with custom annotations or method patterns
 */
@Aspect
@Component
public class MetricsAspect {

    private static final Logger logger = LoggerFactory.getLogger(MetricsAspect.class);

    private final ApplicationMetrics metrics;

    public MetricsAspect(ApplicationMetrics metrics) {
        this.metrics = metrics;
    }

    /**
     * Log execution time for message creation
     */
    @Around("execution(* pt.sousavf.securemessaging.service.MessageService.createConversationMessage(..))")
    public Object measureMessageCreation(ProceedingJoinPoint joinPoint) throws Throwable {
        long startTime = System.currentTimeMillis();
        try {
            Object result = joinPoint.proceed();
            metrics.recordMessageCreated();
            return result;
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            if (duration > 100) {  // Log if takes more than 100ms
                logger.debug("Message creation took {}ms", duration);
            }
        }
    }

    /**
     * Log execution time for conversation creation
     */
    @Around("execution(* pt.sousavf.securemessaging.service.ConversationService.createConversation(..))")
    public Object measureConversationCreation(ProceedingJoinPoint joinPoint) throws Throwable {
        long startTime = System.currentTimeMillis();
        try {
            Object result = joinPoint.proceed();
            metrics.recordConversationCreated();
            return result;
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            if (duration > 100) {
                logger.debug("Conversation creation took {}ms", duration);
            }
        }
    }

    /**
     * Log execution time for message retrieval
     */
    @Around("execution(* pt.sousavf.securemessaging.service.MessageService.getConversationMessages*(..))")
    public Object measureMessageRetrieval(ProceedingJoinPoint joinPoint) throws Throwable {
        long startTime = System.currentTimeMillis();
        try {
            Object result = joinPoint.proceed();
            metrics.recordMessageRetrieved();
            return result;
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            if (duration > 500) {  // Log if takes more than 500ms
                logger.warn("Slow message retrieval: {}ms for {}", duration, joinPoint.getSignature().getName());
            } else if (duration > 100) {
                logger.debug("Message retrieval took {}ms", duration);
            }
        }
    }
}
