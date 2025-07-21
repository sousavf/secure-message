package pt.sousavf.securemessaging.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/support/contact")
public class SupportController {

    @GetMapping
    public String support() {
        return "support";
    }
}