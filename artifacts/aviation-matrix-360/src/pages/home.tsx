import { motion } from "framer-motion";
import { Link } from "wouter";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { toast } from "@/hooks/use-toast";
import { ArrowRight, Activity, BookOpen, GraduationCap, Mail, Info } from "lucide-react";

const contactSchema = z.object({
  name: z.string().min(2, "Name is required"),
  email: z.string().email("Invalid email address"),
  subject: z.string().min(5, "Subject is required"),
  message: z.string().min(10, "Message must be at least 10 characters"),
});

type ContactFormValues = z.infer<typeof contactSchema>;

export default function Home() {
  const form = useForm<ContactFormValues>({
    resolver: zodResolver(contactSchema),
    defaultValues: {
      name: "",
      email: "",
      subject: "",
      message: "",
    },
  });

  const onSubmit = (data: ContactFormValues) => {
    console.log(data);
    toast({
      title: "Message Sent",
      description: "Thank you for contacting Aviation Matrix 360. We will get back to you shortly.",
    });
    form.reset();
  };

  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      {/* Hero Section */}
      <section className="relative pt-32 pb-20 md:pt-48 md:pb-32 overflow-hidden flex-shrink-0">
        <div className="absolute inset-0 bg-primary z-0">
          <div className="absolute inset-0 bg-gradient-to-br from-primary/90 to-primary/40 z-10" />
          <div className="absolute inset-0 bg-[url('https://images.unsplash.com/photo-1542296332-2e4473faf563?q=80&w=2070&auto=format&fit=crop')] bg-cover bg-center opacity-30 mix-blend-overlay z-0" />
        </div>
        
        <div className="container mx-auto px-4 md:px-6 relative z-20">
          <motion.div 
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
            className="max-w-4xl"
          >
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 backdrop-blur border border-white/20 text-white text-sm font-medium mb-6">
              <span className="w-2 h-2 rounded-full bg-secondary animate-pulse" />
              Integrated Aviation Ecosystem
            </div>
            <h1 className="text-5xl md:text-7xl font-bold text-white mb-6 leading-tight tracking-tight">
              Aviation Matrix 360
            </h1>
            <h2 className="text-2xl md:text-3xl text-white/90 font-medium mb-6 leading-snug max-w-3xl">
              Building The Future Of Aviation Through Operations, Education And Innovation
            </h2>
            <p className="text-lg md:text-xl text-white/80 mb-10 max-w-2xl leading-relaxed">
              Aviation Matrix 360 connects operational intelligence, professional development, and future aviation education through one unified ecosystem.
            </p>
            <div className="flex flex-col sm:flex-row gap-4">
              <Link href="/platform">
                <Button size="lg" className="w-full sm:w-auto bg-white text-primary hover:bg-white/90 text-base h-14 px-8 shadow-xl">
                  Explore Platform
                  <ArrowRight className="ml-2 h-5 w-5" />
                </Button>
              </Link>
              <Link href="/academy">
                <Button size="lg" variant="outline" className="w-full sm:w-auto border-white/30 text-white hover:bg-white/10 text-base h-14 px-8 backdrop-blur">
                  Explore Academy
                </Button>
              </Link>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Our Ecosystem Section */}
      <section className="py-24 bg-muted/50">
        <div className="container mx-auto px-4 md:px-6">
          <div className="text-center max-w-3xl mx-auto mb-16">
            <h2 className="text-sm font-bold text-secondary tracking-widest uppercase mb-3">Core Pillars</h2>
            <h3 className="text-3xl md:text-4xl font-bold text-foreground mb-6">Our Ecosystem</h3>
            <div className="h-1 w-20 bg-secondary mx-auto mb-6"></div>
            <p className="text-muted-foreground text-lg">
              A holistic approach to aerospace advancement, bridging the gap between current operations and future potential.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Operations Card */}
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: 0.1 }}
              className="bg-card rounded-xl shadow-lg border border-border p-8 hover:shadow-xl transition-shadow group"
            >
              <div className="h-14 w-14 rounded-lg bg-primary/10 flex items-center justify-center mb-6 group-hover:bg-primary group-hover:text-white transition-colors text-primary">
                <Activity className="h-7 w-7" />
              </div>
              <h4 className="text-xl font-bold mb-2 text-foreground">Operations</h4>
              <p className="text-sm font-semibold text-secondary mb-4">Operational Intelligence and Aviation Systems</p>
              <p className="text-muted-foreground mb-6 leading-relaxed">
                Aviation Matrix 360 helps aviation organizations structure operations, improve visibility, and connect execution with intelligence.
              </p>
              <Link href="/platform" className="inline-flex items-center text-secondary font-medium hover:text-primary transition-colors">
                Learn more <ArrowRight className="ml-1 h-4 w-4" />
              </Link>
            </motion.div>

            {/* Education Card */}
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: 0.2 }}
              className="bg-card rounded-xl shadow-lg border border-border p-8 hover:shadow-xl transition-shadow group"
            >
              <div className="h-14 w-14 rounded-lg bg-primary/10 flex items-center justify-center mb-6 group-hover:bg-primary group-hover:text-white transition-colors text-primary">
                <BookOpen className="h-7 w-7" />
              </div>
              <h4 className="text-xl font-bold mb-2 text-foreground">Education</h4>
              <p className="text-sm font-semibold text-secondary mb-4">Professional Aviation Learning and Development</p>
              <p className="text-muted-foreground mb-6 leading-relaxed">
                Aviation Matrix Academy supports aviation professionals with operational knowledge, structured learning, and industry-focused development.
              </p>
              <Link href="/academy" className="inline-flex items-center text-secondary font-medium hover:text-primary transition-colors">
                Learn more <ArrowRight className="ml-1 h-4 w-4" />
              </Link>
            </motion.div>

            {/* Future Generations Card */}
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: 0.3 }}
              className="bg-card rounded-xl shadow-lg border border-border p-8 hover:shadow-xl transition-shadow group"
            >
              <div className="h-14 w-14 rounded-lg bg-primary/10 flex items-center justify-center mb-6 group-hover:bg-primary group-hover:text-white transition-colors text-primary">
                <GraduationCap className="h-7 w-7" />
              </div>
              <h4 className="text-xl font-bold mb-2 text-foreground">Future Generations</h4>
              <p className="text-sm font-semibold text-secondary mb-4">Kids Aviation Matrix Educational Programs</p>
              <p className="text-muted-foreground mb-6 leading-relaxed">
                Kids Aviation Matrix introduces children to aviation, airports, aircraft, operations, and aviation careers through engaging educational experiences.
              </p>
              <Link href="/academy" className="inline-flex items-center text-secondary font-medium hover:text-primary transition-colors">
                Learn more <ArrowRight className="ml-1 h-4 w-4" />
              </Link>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Our Vision Section */}
      <section className="py-24 bg-primary text-white relative overflow-hidden">
        <div className="absolute inset-0 bg-[url('https://images.unsplash.com/photo-1436491865332-7a61a109cc05?q=80&w=2074&auto=format&fit=crop')] bg-cover bg-center opacity-10 mix-blend-overlay z-0" />
        <div className="container mx-auto px-4 md:px-6 relative z-10">
          <div className="max-w-4xl mx-auto text-center">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              <h2 className="text-sm font-bold text-secondary tracking-widest uppercase mb-4">Our Vision</h2>
              <blockquote className="text-3xl md:text-5xl font-medium leading-tight mb-8">
                "To build a connected aviation ecosystem where operations, knowledge, and future generations work together through one unified framework."
              </blockquote>
              <div className="h-1 w-20 bg-secondary mx-auto"></div>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Contact Section */}
      <section className="py-24 bg-background" id="contact">
        <div className="container mx-auto px-4 md:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-16">
            <div>
              <h2 className="text-sm font-bold text-secondary tracking-widest uppercase mb-3">Get in Touch</h2>
              <h3 className="text-3xl md:text-4xl font-bold text-foreground mb-6">Connect With Us</h3>
              <div className="h-1 w-20 bg-secondary mb-8"></div>
              <p className="text-muted-foreground text-lg mb-10 max-w-md">
                Whether you're looking to optimize your operations or advance your professional education, Aviation Matrix 360 is ready to partner with you.
              </p>
              
              <div className="space-y-6">
                <div className="flex items-start gap-4">
                  <div className="h-12 w-12 rounded-full bg-primary/5 flex items-center justify-center text-primary shrink-0">
                    <Mail className="h-5 w-5" />
                  </div>
                  <div>
                    <h5 className="font-bold text-foreground">Email</h5>
                    <a href="mailto:info@aviationmatrix360.com" className="text-secondary hover:underline mt-1 block">
                      info@aviationmatrix360.com
                    </a>
                  </div>
                </div>

                <div className="flex items-start gap-4">
                  <div className="h-12 w-12 rounded-full bg-primary/5 flex items-center justify-center text-primary shrink-0">
                    <Info className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="text-muted-foreground mt-1 italic">
                      Official contact details will be announced soon.
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-card rounded-2xl shadow-xl border border-border p-8 md:p-10">
              <h4 className="text-2xl font-bold mb-6">Send a Message</h4>
              <Form {...form}>
                <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <FormField
                      control={form.control}
                      name="name"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Full Name</FormLabel>
                          <FormControl>
                            <Input placeholder="John Doe" {...field} className="bg-muted/50" />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="email"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Email Address</FormLabel>
                          <FormControl>
                            <Input placeholder="john@company.com" {...field} className="bg-muted/50" />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>
                  <FormField
                    control={form.control}
                    name="subject"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Subject</FormLabel>
                        <FormControl>
                          <Input placeholder="How can we help?" {...field} className="bg-muted/50" />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={form.control}
                    name="message"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Message</FormLabel>
                        <FormControl>
                          <Textarea 
                            placeholder="Please provide details about your inquiry..." 
                            className="min-h-[150px] bg-muted/50 resize-y"
                            {...field} 
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <Button type="submit" size="lg" className="w-full bg-primary text-white hover:bg-primary/90">
                    Send Message
                  </Button>
                </form>
              </Form>
            </div>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
