// Configuration for Melbourne Medical Clinic Voice Agent

export const CLINIC_CONFIG = {
    name: "Melbourne Medical Clinic",
    timezone: "Australia/Melbourne",
    greeting: "Hello and welcome to Melbourne Medical Clinic. How can I help you today?",

    // Business hours (24-hour format)
    hours: {
        open: 9,  // 9 AM
        close: 17, // 5 PM
        days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    },

    // Appointment slot duration in minutes
    slotDuration: 30
};

export const DOCTORS = [
    {
        id: "dr-chen",
        name: "Dr. Sarah Chen",
        gender: "female",
        specialty: "General Practice",
        description: "Dr. Chen is our experienced female GP available for general consultations.",
        availability: {
            Monday: { start: 9, end: 17 },
            Tuesday: { start: 9, end: 17 },
            Wednesday: { start: 9, end: 13 }, // Half day
            Thursday: { start: 9, end: 17 },
            Friday: { start: 9, end: 17 }
        }
    },
    {
        id: "dr-wilson",
        name: "Dr. James Wilson",
        gender: "male",
        specialty: "General Practice",
        description: "Dr. Wilson is our male GP with over 15 years of experience.",
        availability: {
            Monday: { start: 9, end: 17 },
            Tuesday: { start: 9, end: 17 },
            Wednesday: { start: 9, end: 17 },
            Thursday: { start: 9, end: 17 },
            Friday: { start: 9, end: 13 } // Half day
        }
    },
    {
        id: "dr-parker",
        name: "Dr. Emily Parker",
        gender: "female",
        specialty: "Pediatrics",
        description: "Dr. Parker specializes in children's health and is wonderful with kids of all ages.",
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
