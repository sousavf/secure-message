package pt.sousavf.securemessaging.controller;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.List;
import java.util.Collections;

/**
 * Controller for Apple Universal Links support
 * Serves the Apple App Site Association file required for iOS universal links
 */
@RestController
public class UniversalLinksController {

    /**
     * Apple App Site Association endpoint
     * This endpoint serves the JSON file that iOS uses to determine which URLs
     * should be handled by the Safe Whisper app instead of opening in Safari
     * 
     * @return Apple App Site Association JSON
     */
    @GetMapping(value = "/.well-known/apple-app-site-association", 
                produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> getAppleAppSiteAssociation() {
        
        // Create the Apple App Site Association structure
        Map<String, Object> applinks = Map.of(
            "apps", Collections.emptyList(),
            "details", List.of(
                Map.of(
                    "appID", "RJ3GB6YDXL.pt.sousavf.Safe-Whisper",
                    "paths", List.of(
                        "NOT /support/contact",
                        "NOT /privacy/policy", 
                        "NOT /about/me",
                        "/*"
                    )
                )
            )
        );
        
        Map<String, Object> response = Map.of("applinks", applinks);
        
        return ResponseEntity.ok()
            .header("Content-Type", "application/json")
            .header("Cache-Control", "max-age=3600") // Cache for 1 hour
            .body(response);
    }
    
    /**
     * Alternative endpoint without .well-known prefix for testing
     * This can be useful for debugging and testing the JSON structure
     * 
     * @return Apple App Site Association JSON
     */
    @GetMapping(value = "/apple-app-site-association", 
                produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> getAppleAppSiteAssociationAlternative() {
        return getAppleAppSiteAssociation();
    }
}