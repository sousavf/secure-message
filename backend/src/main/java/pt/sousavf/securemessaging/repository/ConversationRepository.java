package pt.sousavf.securemessaging.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import pt.sousavf.securemessaging.entity.Conversation;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    /**
     * Find all conversations initiated by a user
     */
    List<Conversation> findByInitiatorUserId(UUID initiatorUserId);

    /**
     * Find all active conversations initiated by a user
     */
    @Query("SELECT c FROM Conversation c WHERE c.initiatorUserId = :userId AND c.status = 'ACTIVE' AND c.expiresAt > CURRENT_TIMESTAMP")
    List<Conversation> findActiveByInitiatorUserId(@Param("userId") UUID userId);

    /**
     * Find conversations that should be marked as expired
     */
    @Query("SELECT c FROM Conversation c WHERE c.status = 'ACTIVE' AND c.expiresAt <= CURRENT_TIMESTAMP")
    List<Conversation> findExpiredConversations();

    /**
     * Find conversations marked as deleted and older than a certain time
     */
    @Query("SELECT c FROM Conversation c WHERE c.status = 'DELETED' AND c.createdAt <= :cutoffTime")
    List<Conversation> findDeletedConversationsOlderThan(@Param("cutoffTime") LocalDateTime cutoffTime);

    /**
     * Check if a conversation exists and is active
     */
    @Query("SELECT COUNT(c) > 0 FROM Conversation c WHERE c.id = :id AND c.status = 'ACTIVE' AND c.expiresAt > CURRENT_TIMESTAMP")
    boolean isActive(@Param("id") UUID id);

    /**
     * Find a conversation by ID with status check
     */
    Optional<Conversation> findById(UUID id);
}
