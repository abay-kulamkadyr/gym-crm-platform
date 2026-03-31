package com.epam.application.messaging.publisher;

import java.util.List;

import com.epam.application.messaging.event.TrainerWorkloadEvent;
import com.epam.domain.model.Training;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "spring.kafka.enabled", havingValue = "false", matchIfMissing = false)
@Slf4j
public class NoopTrainingEventPublisher implements TrainingEventPublisher {
    @Override
    public void publishTrainingCreated(TrainerWorkloadEvent event) {
        log.debug("Kafka disabled - skipping event publish: {}", event);
    }

    @Override
    public void publishTrainingDeleted(TrainerWorkloadEvent event) {
        log.debug("Kafka disabled - skipping event publish: {}", event);
    }

    @Override
    public void publishDeleteEventsForTrainings(List<Training> trainings) {
        log.debug("Kafka disabled - skipping event");
    }
}
