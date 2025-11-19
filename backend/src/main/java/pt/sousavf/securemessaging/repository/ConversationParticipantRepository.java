package pt.sousavf.securemessaging.repository;

import pt.sousavf.securemessaging.entity.ConversationParticipant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConversationParticipantRepository extends JpaRepository<ConversationParticipant, UUID> {

    /**
     * Find a participant by conversation and device
     */
    @Query("SELECT p FROM ConversationParticipant p WHERE p.conversationId = :conversationId AND p.deviceId = :deviceId")
    Optional<ConversationParticipant> findByConversationAndDevice(@Param("conversationId") UUID conversationId, @Param("deviceId") String deviceId);

    /**
     * Find all active participants in a conversation (haven't departed)
     */
    @Query("SELECT p FROM ConversationParticipant p WHERE p.conversationId = :conversationId AND p.departedAt IS NULL")
    List<ConversationParticipant> findActiveParticipants(@Param("conversationId") UUID conversationId);

    /**
     * Count active participants in a conversation
     */
    @Query("SELECT COUNT(p) FROM ConversationParticipant p WHERE p.conversationId = :conversationId AND p.departedAt IS NULL")
    long countActiveParticipants(@Param("conversationId") UUID conversationId);

    /**
     * Find all participants for a conversation (including departed)
     */
    List<ConversationParticipant> findByConversationId(UUID conversationId);

    /**
     * Check if a device is an active participant
     */
    @Query("SELECT CASE WHEN COUNT(p) > 0 THEN true ELSE false END FROM ConversationParticipant p WHERE p.conversationId = :conversationId AND p.deviceId = :deviceId AND p.departedAt IS NULL")
    boolean isActiveParticipant(@Param("conversationId") UUID conversationId, @Param("deviceId") String deviceId);

    /**
     * Delete all participants for a conversation
     */
    int deleteByConversationId(UUID conversationId);

    /**
     * Check if conversation already has a secondary participant (link consumed)
     */
    @Query("SELECT CASE WHEN COUNT(p) > 0 THEN true ELSE false END FROM ConversationParticipant p WHERE p.conversationId = :conversationId AND p.isInitiator = false AND p.linkConsumedAt IS NOT NULL")
    boolean hasSecondaryParticipant(@Param("conversationId") UUID conversationId);

    /**
     * Count total active participants (including initiator)
     */
    @Query("SELECT COUNT(p) FROM ConversationParticipant p WHERE p.conversationId = :conversationId AND p.departedAt IS NULL")
    long countTotalActiveParticipants(@Param("conversationId") UUID conversationId);
}
