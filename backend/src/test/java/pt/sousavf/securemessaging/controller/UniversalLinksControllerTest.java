package pt.sousavf.securemessaging.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.web.WebAppConfiguration;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class UniversalLinksControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void testAppleAppSiteAssociation() throws Exception {
        mockMvc.perform(get("/.well-known/apple-app-site-association"))
                .andExpect(status().isOk())
                .andExpect(content().contentType("application/json"))
                .andExpect(header().string("Cache-Control", "max-age=3600"))
                .andExpect(jsonPath("$.applinks").exists())
                .andExpect(jsonPath("$.applinks.apps").isArray())
                .andExpect(jsonPath("$.applinks.apps").isEmpty())
                .andExpect(jsonPath("$.applinks.details").isArray())
                .andExpect(jsonPath("$.applinks.details", hasSize(1)))
                .andExpect(jsonPath("$.applinks.details[0].appID", is("RJ3GB6YDXL.pt.sousavf.Safe-Whisper")))
                .andExpect(jsonPath("$.applinks.details[0].paths").isArray())
                .andExpect(jsonPath("$.applinks.details[0].paths", hasSize(4)))
                .andExpect(jsonPath("$.applinks.details[0].paths[0]", is("NOT /support/contact")))
                .andExpect(jsonPath("$.applinks.details[0].paths[1]", is("NOT /privacy/policy")))
                .andExpect(jsonPath("$.applinks.details[0].paths[2]", is("NOT /about/me")))
                .andExpect(jsonPath("$.applinks.details[0].paths[3]", is("/*")));
    }

    @Test
    void testAppleAppSiteAssociationAlternative() throws Exception {
        mockMvc.perform(get("/apple-app-site-association"))
                .andExpect(status().isOk())
                .andExpect(content().contentType("application/json"))
                .andExpect(header().string("Cache-Control", "max-age=3600"))
                .andExpect(jsonPath("$.applinks").exists());
    }
}