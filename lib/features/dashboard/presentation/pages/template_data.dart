import '../../../../core/models/choice_option.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/form_image.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question.dart';
import '../../../../core/models/question_kind.dart';

class FormTemplate {
  final String title;
  final String category;
  final String imagePath;
  final List<Item> items;

  const FormTemplate({
    required this.title,
    required this.category,
    required this.imagePath,
    required this.items,
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Item _q(String id, String title, QuestionKind kind, {bool required = false}) =>
    Item(
      itemId: id,
      title: title,
      content: QuestionItemContent(
        question: Question(questionId: 'q$id', required: required, kind: kind),
      ),
    );

ChoiceQuestion _radio(List<String> options) => ChoiceQuestion(
      type: ChoiceType.radio,
      options: options.map((v) => ChoiceOption(value: v)).toList(),
    );

ChoiceQuestion _checkbox(List<String> options) => ChoiceQuestion(
      type: ChoiceType.checkbox,
      options: options.map((v) => ChoiceOption(value: v)).toList(),
    );

const _text = TextQuestion();
const _paragraph = TextQuestion(paragraph: true);

// ── Work ──────────────────────────────────────────────────────────────────────

final _contactInfo = FormTemplate(
  title: 'Contact Information',
  category: 'Work',
  imagePath: 'assets/template_image/contact_information.png',
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Email', _text, required: true),
    _q('3', 'Address', _paragraph, required: true),
    _q('4', 'Phone number', _text, required: true),
    _q('5', 'Comments', _paragraph),
  ],
);

final _customerFeedback = FormTemplate(
  title: 'Customer Feedback',
  category: 'Work',
  imagePath: 'assets/template_image/customer_feedback.png',
  items: [
    _q('1', 'Full name', _text),
    _q('2', 'Email address', _text),
    _q('3', 'How satisfied are you with our product or service?',
        _radio(['Very satisfied', 'Satisfied', 'Neutral', 'Dissatisfied', 'Very dissatisfied']),
        required: true),
    _q('4', 'What did we do well?', _paragraph),
    _q('5', 'What could we improve?', _paragraph),
    _q('6', 'Would you recommend us to others?',
        _radio(['Definitely', 'Probably', 'Not sure', 'Probably not', 'Definitely not'])),
    _q('7', 'Any other comments?', _paragraph),
  ],
);

final _workRequest = FormTemplate(
  title: 'Work Request',
  category: 'Work',
  imagePath: 'assets/template_image/work_request.png',
  items: [
    _q('1', 'Requester name', _text, required: true),
    _q('2', 'Email address', _text, required: true),
    _q('3', 'Department', _text),
    _q('4', 'Request title', _text, required: true),
    _q('5', 'Description of work needed', _paragraph, required: true),
    _q('6', 'Priority', _radio(['Low', 'Medium', 'High', 'Urgent']), required: true),
    _q('7', 'Requested completion date', const DateQuestion()),
    _q('8', 'Additional notes', _paragraph),
  ],
);

final _orderForm = FormTemplate(
  title: 'Order Form',
  category: 'Work',
  imagePath: 'assets/template_image/order_form.png',
  items: [
    _q('1', 'Full name', _text, required: true),
    _q('2', 'Email address', _text, required: true),
    _q('3', 'Phone number', _text),
    _q('4', 'Delivery address', _paragraph, required: true),
    _q('5', 'Item(s) ordered', _paragraph, required: true),
    _q('6', 'Quantity', _text, required: true),
    _q('7', 'Payment method',
        _radio(['Credit card', 'Debit card', 'Bank transfer', 'Cash on delivery'])),
    _q('8', 'Special instructions', _paragraph),
  ],
);

final _jobApplication = FormTemplate(
  title: 'Job Application',
  category: 'Work',
  imagePath: 'assets/template_image/job_application.png',
  items: [
    _q('1', 'Full name', _text, required: true),
    _q('2', 'Email address', _text, required: true),
    _q('3', 'Phone number', _text, required: true),
    _q('4', 'Position applying for', _text, required: true),
    _q('5', 'LinkedIn profile URL', _text),
    _q('6', 'Years of relevant experience',
        _radio(['Less than 1 year', '1–3 years', '3–5 years', '5–10 years', '10+ years'])),
    _q('7', 'How did you hear about this role?',
        _radio(['LinkedIn', 'Job board', 'Company website', 'Referral', 'Other'])),
    _q('8', 'Cover letter / motivation', _paragraph, required: true),
  ],
);

final _timeOffRequest = FormTemplate(
  title: 'Time Off Request',
  category: 'Work',
  imagePath: 'assets/template_image/time_off_request.png',
  items: [
    _q('1', 'Employee name', _text, required: true),
    _q('2', 'Email address', _text, required: true),
    _q('3', 'Department / team', _text),
    _q('4', 'Type of leave',
        _radio(['Annual leave', 'Sick leave', 'Parental leave', 'Unpaid leave', 'Other']),
        required: true),
    _q('5', 'Start date', const DateQuestion(), required: true),
    _q('6', 'End date', const DateQuestion(), required: true),
    _q('7', 'Reason (optional)', _paragraph),
    _q('8', 'Cover arrangements', _paragraph),
  ],
);

// ── Personal ──────────────────────────────────────────────────────────────────

final _rsvp = FormTemplate(
  title: 'RSVP',
  category: 'Personal',
  imagePath: 'assets/template_image/rsvp.png',
  items: [
    _q('1', 'Can you attend?', _radio(['Yes, I\'ll be there', 'Sorry, can\'t make it']),
        required: true),
    _q('2', 'What are the names of people attending?', _paragraph),
    _q('3', 'How did you hear about this event?',
        _radio(['Website', 'Friend', 'Newsletter', 'Advertisement'])),
    _q('4', 'Comments and/or questions', _paragraph),
  ],
);

final _eventRegistration = FormTemplate(
  title: 'Event Registration',
  category: 'Personal',
  imagePath: 'assets/template_image/event_registration.png',
  items: [
    _q('1', 'Full name', _text, required: true),
    _q('2', 'Email address', _text, required: true),
    _q('3', 'Phone number', _text),
    _q('4', 'Organisation or affiliation', _text),
    _q('5', 'Which sessions will you attend?',
        _checkbox(['Morning keynote', 'Workshop A', 'Workshop B', 'Afternoon panel', 'Networking dinner'])),
    _q('6', 'T-shirt size', _radio(['XS', 'S', 'M', 'L', 'XL', 'XXL'])),
    _q('7', 'Special requirements or accessibility needs', _paragraph),
  ],
);

final _eventFeedback = FormTemplate(
  title: 'Event Feedback',
  category: 'Personal',
  imagePath: 'assets/template_image/event_feedback.png',
  items: [
    _q('1', 'Overall, how would you rate the event?',
        _radio(['Excellent', 'Good', 'Average', 'Poor']), required: true),
    _q('2', 'What did you enjoy most?', _paragraph),
    _q('3', 'What could be improved?', _paragraph),
    _q('4', 'Would you recommend this event to others?',
        _radio(['Definitely', 'Probably', 'Not sure', 'No'])),
    _q('5', 'Any other comments?', _paragraph),
  ],
);

final _partyInvite = FormTemplate(
  title: 'Party Invite',
  category: 'Personal',
  imagePath: 'assets/template_image/party_invite.png',
  items: [
    _q('1', 'What is your name?', _text),
    _q('2', 'Can you attend?',
        _radio(['Yes, I\'ll be there', 'Sorry, can\'t make it']),
        required: true),
    _q('3', 'How many of you are attending?', _text),
    _q('4', 'What will you be bringing?',
        _checkbox(['Mains', 'Salad', 'Dessert', 'Drinks', 'Sides/Appetizers'])),
    _q('5', 'Do you have any allergies or dietary restrictions?', _text),
    _q('6', 'What is your email address?', _text),
  ],
);

final _tshirtSignup = FormTemplate(
  title: 'T-Shirt Sign Up',
  category: 'Personal',
  imagePath: 'assets/template_image/tshirt_size.png',
  items: [
    _q('1', 'Name', _text, required: true),
    _q('2', 'Shirt size', _radio(['XS', 'S', 'M', 'L', 'XL'])),
    Item(
      itemId: 'img1',
      title: 'T-Shirt Preview',
      content: ImageItemContent(
        image: FormImage(
          sourceUri:
              'https://lh7-rt.googleusercontent.com/formsz/AN7BsVADpMZ-JJ5UqkmHXIXyxdrvbiJ0IeQexMTgyExz8wC-UxO_JrZ1V7MtOOi77QJuRZgvdmU4ZkxYhVoo-ZchMlDkXmFzXyQh07wWrKYIJh4bFj-OEA5KV3_GqwdAruDLnU6Oo4ukcCzmlXlbO1gnvdfr447C2hI30Bwh=s2048?key=vQL4MrQ8tNixKDs5NZhxqQ',
        ),
      ),
    ),
    _q('3', 'Other thoughts or comments', _paragraph),
  ],
);

final _findATime = FormTemplate(
  title: 'Find a Time',
  category: 'Personal',
  imagePath: 'assets/template_image/find_a_time.png',
  items: [
    _q('1', 'What times are you available? – Days',
        _checkbox(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']),
        required: true),
    _q('2', 'What times are you available? – Time of day',
        _checkbox(['Morning', 'Midday', 'Afternoon', 'Evening']),
        required: true),
    _q('3', 'Items to discuss?', _paragraph),
    _q('4', 'Allergies or dietary restrictions?',
        _radio(['Vegetarian', 'Vegan', 'Kosher', 'Halal', 'Gluten-free', 'None'])),
    _q('5', 'Any other comments and/or questions?', _paragraph),
  ],
);

// ── Education ─────────────────────────────────────────────────────────────────

final _courseEvaluation = FormTemplate(
  title: 'Course Evaluation',
  category: 'Education',
  imagePath: 'assets/template_image/course_evaluation.png',
  items: [
    _q('1', 'Course name', _text, required: true),
    _q('2', 'Instructor name', _text),
    _q('3', 'How would you rate the course overall?',
        _radio(['5 – Excellent', '4 – Good', '3 – Average', '2 – Below average', '1 – Poor']),
        required: true),
    _q('4', 'The course content was well organised',
        _radio(['Strongly agree', 'Agree', 'Neutral', 'Disagree', 'Strongly disagree'])),
    _q('5', 'The instructor explained concepts clearly',
        _radio(['Strongly agree', 'Agree', 'Neutral', 'Disagree', 'Strongly disagree'])),
    _q('6', 'What did you find most valuable?', _paragraph),
    _q('7', 'What would you improve?', _paragraph),
  ],
);

final _exitTicket = FormTemplate(
  title: 'Exit Ticket',
  category: 'Education',
  imagePath: 'assets/template_image/exit_ticket.png',
  items: [
    _q('1', 'Student name', _text, required: true),
    _q('2', 'Today\'s date', const DateQuestion(), required: true),
    _q('3', 'What is the most important thing you learned today?', _paragraph, required: true),
    _q('4', 'What question do you still have?', _paragraph),
    _q('5', 'How confident do you feel about today\'s topic?',
        _radio(['Very confident', 'Somewhat confident', 'Not very confident', 'Not confident at all'])),
    _q('6', 'Rate today\'s lesson',
        _radio(['Excellent', 'Good', 'OK', 'Needs improvement'])),
  ],
);

final _blankQuiz = FormTemplate(
  title: 'Blank Quiz',
  category: 'Education',
  imagePath: 'assets/template_image/blank_quiz.png',
  items: [
    _q('1', 'Student name', _text, required: true),
    _q('2', 'Question 1', _radio(['Option A', 'Option B', 'Option C', 'Option D']), required: true),
    _q('3', 'Question 2', _radio(['Option A', 'Option B', 'Option C', 'Option D']), required: true),
    _q('4', 'Question 3', _radio(['True', 'False']), required: true),
    _q('5', 'Short answer question', _text, required: true),
  ],
);

final _assessment = FormTemplate(
  title: 'Assessment',
  category: 'Education',
  imagePath: 'assets/template_image/assessment.png',
  items: [
    _q('1', 'Student name', _text, required: true),
    _q('2', 'Student ID', _text),
    _q('3', 'Date', const DateQuestion(), required: true),
    _q('4', 'Assessment title', _text, required: true),
    _q('5', 'Section 1: Multiple choice',
        _radio(['Option A', 'Option B', 'Option C', 'Option D']), required: true),
    _q('6', 'Section 2: True or False',
        _radio(['True', 'False']), required: true),
    _q('7', 'Section 3: Short answer', _text, required: true),
    _q('8', 'Section 4: Extended response', _paragraph, required: true),
  ],
);

final _worksheet = FormTemplate(
  title: 'Worksheet',
  category: 'Education',
  imagePath: 'assets/template_image/worksheet.png',
  items: [
    _q('1', 'Student name', _text, required: true),
    _q('2', 'Class / subject', _text),
    _q('3', 'Date', const DateQuestion()),
    _q('4', 'Question 1', _paragraph, required: true),
    _q('5', 'Question 2', _paragraph, required: true),
    _q('6', 'Question 3', _paragraph, required: true),
    _q('7', 'Reflection: What did you learn?', _paragraph),
  ],
);

// ── Master list ───────────────────────────────────────────────────────────────

final List<FormTemplate> kFormTemplates = [
  // Work
  _contactInfo,
  _customerFeedback,
  _workRequest,
  _orderForm,
  _jobApplication,
  _timeOffRequest,
  // Personal
  _rsvp,
  _eventRegistration,
  _eventFeedback,
  _partyInvite,
  _tshirtSignup,
  _findATime,
  // Education
  _courseEvaluation,
  _exitTicket,
  _blankQuiz,
  _worksheet,
  _assessment,
];

final List<String> kTemplateCategories = ['Work', 'Personal', 'Education'];
