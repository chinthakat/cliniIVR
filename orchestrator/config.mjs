// Configuration for Melbourne Medical Clinic Voice Agent

export const CLINIC_CONFIG = {
    name: "Melbourne Medical Clinic",
    timezone: "Australia/Melbourne",
    // Dynamic greetings
    greetings: {
        morning: [
            "Good morning, thanks for calling Melbourne Medical Clinic. This is Sarah. How can I look after you today?",
            "Good morning, Melbourne Medical Clinic. How may I help you?",
            "Hi, good morning! You've reached Melbourne Medical Clinic. How can I help?"
        ],
        afternoon: [
            "Good afternoon, Melbourne Medical Clinic. How can I help you today?",
            "Thanks for calling Melbourne Medical Clinic. This is Sarah. How may I assist you?",
            "Hello, good afternoon! Melbourne Medical Clinic. How can I help?"
        ],
        evening: [
            "Good evening, Melbourne Medical Clinic. How can I help you?",
            "Thanks for calling Melbourne Medical Clinic. How may I assist you tonight?"
        ]
    },

    // Appointment slot duration in minutes
    slotDuration: 30
};

export const DOCTORS = [
    {
        id: "dr-perera",
        name: "Dr. Kasun Perera",
        gender: "male",
        specialty: "General Practice",
        description: "Dr. Perera is our experienced GP available for general consultations.",
        availability: {
            Monday: { start: 9, end: 17 },
            Tuesday: { start: 9, end: 17 },
            Wednesday: { start: 9, end: 13 }, // Half day
            Thursday: { start: 9, end: 17 },
            Friday: { start: 9, end: 17 }
        }
    },
    {
        id: "dr-jayasinghe",
        name: "Dr. Nimal Jayasinghe",
        gender: "male",
        specialty: "General Practice",
        description: "Dr. Jayasinghe is our male GP with over 15 years of experience.",
        availability: {
            Monday: { start: 9, end: 17 },
            Tuesday: { start: 9, end: 17 },
            Wednesday: { start: 9, end: 17 },
            Thursday: { start: 9, end: 17 },
            Friday: { start: 9, end: 13 } // Half day
        }
    },
    {
        id: "dr-fernando",
        name: "Dr. Sachini Fernando",
        gender: "female",
        specialty: "General Practice",
        description: "Dr. Fernando is our female GP, great with patients of all ages.",
        availability: {
            Monday: { start: 9, end: 17 },
            Tuesday: { start: 9, end: 17 },
            Wednesday: { start: 9, end: 17 },
            Thursday: { start: 9, end: 17 },
            Friday: { start: 9, end: 17 }
        }
    }
];

// Get doctor by ID
export function getDoctorById(id) {
    return DOCTORS.find(d => d.id === id);
}

// Get doctors by preference (gender, specialty, etc.)
export function findDoctors(preferences = {}) {
    return DOCTORS.filter(doctor => {
        if (preferences.gender && doctor.gender !== preferences.gender) return false;
        if (preferences.specialty && !doctor.specialty.toLowerCase().includes(preferences.specialty.toLowerCase())) return false;
        if (preferences.forChildren && doctor.specialty !== "Pediatrics") return false;
        return true;
    });
}

// Generate available time slots for a doctor on a given day
export function getAvailableSlots(doctorId, dayOfWeek) {
    const doctor = getDoctorById(doctorId);
    if (!doctor) return [];

    const dayAvailability = doctor.availability[dayOfWeek];
    if (!dayAvailability) return [];

    const slots = [];
    for (let hour = dayAvailability.start; hour < dayAvailability.end; hour++) {
        slots.push(`${hour}:00`);
        slots.push(`${hour}:30`);
    }
    return slots;
}

// Format time for speech (e.g., "9:30" -> "nine thirty AM")
export function formatTimeForSpeech(time) {
    const [hour, minute] = time.split(':').map(Number);
    const period = hour >= 12 ? 'PM' : 'AM';
    const displayHour = hour > 12 ? hour - 12 : hour;
    const minuteText = minute === 0 ? "o'clock" : minute.toString();
    return `${displayHour}:${minute.toString().padStart(2, '0')} ${period}`;
}
