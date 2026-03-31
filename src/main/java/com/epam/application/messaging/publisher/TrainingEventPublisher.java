package com.epam.application.messaging.publisher;

import java.util.List;

import com.epam.application.messaging.event.TrainerWorkloadEvent;
import com.epam.domain.model.Training;

public interface TrainingEventPublisher {
    void publishTrainingCreated(TrainerWorkloadEvent event);

    void publishTrainingDeleted(TrainerWorkloadEvent event);

    void publishDeleteEventsForTrainings(List<Training> trainings);
}
