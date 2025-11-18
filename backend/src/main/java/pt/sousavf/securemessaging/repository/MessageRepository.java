package pt.sousavf.securemessaging.repository;

import pt.sousavf.securemessaging.entity.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MessageRepository extends JpaRepository<Message, UUID> {

    @Query("SELECT m FROM Message m WHERE m.id = :id AND m.consumed = false AND m.expiresAt > :now")
    Optional<Message> findAvailableMessage(@Param("id") UUID id, @Param("now") LocalDateTime now);

    @Modifying
    @Query("DELETE FROM Message m WHERE m.expiresAt < :now")
    int deleteExpiredMessages(@Param("now") LocalDateTime now);

    @Modifying
    @Query("DELETE FROM Message m WHERE m.consumed = true AND m.readAt < :threshold")
    int deleteConsumedMessages(@Param("threshold") LocalDateTime threshold);

    @Query("SELECT COUNT(m) FROM Message m WHERE DATE(m.createdAt) = DATE(:date)")
    long countMessagesCreatedOnDate(@Param("date") LocalDateTime date);

    @Query("SELECT COUNT(m) FROM Message m WHERE DATE(m.readAt) = DATE(:date) AND m.consumed = true")
    long countMessagesReadOnDate(@Param("date") LocalDateTime date);

    @Query("SELECT m FROM Message m WHERE m.expiresAt < :now")
    List<Message> findExpiredMessages(@Param("now") LocalDateTime now);

    @Query("SELECT COUNT(m) FROM Message m WHERE m.consumed = false AND m.expiresAt > :now")
    long countActiveMessages(@Param("now") LocalDateTime now);

    @Query("SELECT COUNT(m) FROM Message m WHERE m.consumed = true")
    long countConsumedMessages();

    /**
     * Find all messages for a conversation
     */
    List<Message> findByConversationId(UUID conversationId);

    /**
     * Find all active messages for a conversation
     */
    @Query("SELECT m FROM Message m WHERE m.conversationId = :conversationId AND m.expiresAt > CURRENT_TIMESTAMP ORDER BY m.createdAt ASC")
    List<Message> findActiveByConversationId(@Param("conversationId") UUID conversationId);

    /**
     * Delete all messages for a conversation
     */
    @Modifying
    @Query("DELETE FROM Message m WHERE m.conversationId = :conversationId")
    int deleteByConversationId(@Param("conversationId") UUID conversationId);

    /**
     * Count active messages in a conversation
     */
    @Query("SELECT COUNT(m) FROM Message m WHERE m.conversationId = :conversationId AND m.expiresAt > CURRENT_TIMESTAMP")
    long countActiveByConversationId(@Param("conversationId") UUID conversationId);
}