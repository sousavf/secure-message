package pt.sousavf.securemessaging.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pt.sousavf.securemessaging.entity.DeviceToken;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {

    /**
     * Find a device token by device ID
     */
    Optional<DeviceToken> findByDeviceId(String deviceId);

    /**
     * Find all device tokens by device ID (in case of multiple registrations)
     */
    List<DeviceToken> findAllByDeviceId(String deviceId);

    /**
     * Find all device tokens for multiple device IDs
     */
    List<DeviceToken> findByDeviceIdIn(List<String> deviceIds);

    /**
     * Find all active device tokens for a device ID
     */
    List<DeviceToken> findByDeviceIdAndActiveTrue(String deviceId);

    /**
     * Find a device token by APNs token
     */
    Optional<DeviceToken> findByApnsToken(String apnsToken);

    /**
     * Check if a device has a registered token
     */
    boolean existsByDeviceId(String deviceId);
}
