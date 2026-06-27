import { motion } from "framer-motion";
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
import { MapPin, Phone, Mail, Clock } from "lucide-react";

const contactSchema = z.object({
  name: z.string().min(2, "Name is required"),
  email: z.string().email("Invalid email address"),
  subject: z.string().min(5, "Subject is required"),
  message: z.string().min(10, "Message must be at least 10 characters"),
});

type ContactFormValues = z.infer<typeof contactSchema>;

export default function Contact() {
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
      title: "Message Sent Successfully",
      description: "A representative from Aviation Matrix 360 will contact you shortly.",
    });
    form.reset();
  };

  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      <section className="relative pt-32 pb-20 md:pt-40 md:pb-24 bg-primary overflow-hidden">
        <div className="container mx-auto px-4 md:px-6 relative z-20 text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="max-w-2xl mx-auto"
          >
            <h1 className="text-4xl md:text-6xl font-bold text-white mb-6">Contact Us</h1>
            <p className="text-xl text-white/80">
              Connect with our team to learn more about the Aviation Matrix ecosystem.
            </p>
          </motion.div>
        </div>
      </section>

      <section className="py-24 bg-background flex-grow">
        <div className="container mx-auto px-4 md:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-5 gap-16">
            <div className="lg:col-span-2 space-y-10">
              <div>
                <h3 className="text-2xl font-bold text-foreground mb-6">Headquarters</h3>
                <div className="space-y-6">
                  <div className="flex items-start gap-4">
                    <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary shrink-0">
                      <MapPin className="h-5 w-5" />
                    </div>
                    <div>
                      <h5 className="font-bold text-foreground">Address</h5>
                      <p className="text-muted-foreground mt-1">1 Aviation Way, Sector 4<br />Global Hub, AM 360</p>
                    </div>
                  </div>
                  
                  <div className="flex items-start gap-4">
                    <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary shrink-0">
                      <Phone className="h-5 w-5" />
                    </div>
                    <div>
                      <h5 className="font-bold text-foreground">Phone</h5>
                      <p className="text-muted-foreground mt-1">+1 (800) MATRIX-0</p>
                    </div>
                  </div>
                  
                  <div className="flex items-start gap-4">
                    <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary shrink-0">
                      <Mail className="h-5 w-5" />
                    </div>
                    <div>
                      <h5 className="font-bold text-foreground">Email</h5>
                      <p className="text-muted-foreground mt-1">contact@aviationmatrix360.com</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-4">
                    <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary shrink-0">
                      <Clock className="h-5 w-5" />
                    </div>
                    <div>
                      <h5 className="font-bold text-foreground">Business Hours</h5>
                      <p className="text-muted-foreground mt-1">Monday - Friday<br />8:00 AM - 6:00 PM (EST)</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="lg:col-span-3">
              <div className="bg-card rounded-2xl shadow-lg border border-border p-8 md:p-10">
                <h3 className="text-2xl font-bold mb-8">Send us an Inquiry</h3>
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
                              <Input placeholder="Your Name" {...field} />
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
                              <Input placeholder="your.email@company.com" {...field} />
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
                            <Input placeholder="How can we assist you?" {...field} />
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
                              placeholder="Please provide details..." 
                              className="min-h-[150px] resize-y"
                              {...field} 
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <Button type="submit" size="lg" className="w-full">
                      Submit Message
                    </Button>
                  </form>
                </Form>
              </div>
            </div>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
