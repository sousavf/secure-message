package pt.sousavf.securemessaging.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/privacy/policy")
public class PrivacyController {

    @GetMapping
    public String privacyPolicy() {
        return "privacy-policy";
    }
}