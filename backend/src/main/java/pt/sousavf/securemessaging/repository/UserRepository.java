package pt.sousavf.securemessaging.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import pt.sousavf.securemessaging.entity.User;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
    
    Optional<User> findByDeviceId(String deviceId);
    
    Optional<User> findByOriginalTransactionId(String originalTransactionId);
    
    @Query("SELECT u FROM User u WHERE u.subscriptionExpiresAt <= :now AND u.subscriptionStatus = 'PREMIUM_ACTIVE'")
    List<User> findExpiredPremiumUsers(@Param("now") LocalDateTime now);
    
    @Query("SELECT COUNT(u) FROM User u WHERE u.subscriptionStatus = 'PREMIUM_ACTIVE'")
    long countActivePremiumUsers();
    
    @Query("SELECT COUNT(u) FROM User u WHERE u.subscriptionStatus = 'FREE'")
    long countFreeUsers();
}