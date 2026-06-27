import { motion } from "framer-motion";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { PlaneTakeoff, Shield, Users, Lightbulb } from "lucide-react";

export default function About() {
  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      {/* Hero Section */}
      <section className="relative pt-32 pb-20 md:pt-48 md:pb-32 bg-primary overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-primary/90 to-primary z-10" />
        <div className="container mx-auto px-4 md:px-6 relative z-20 text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="max-w-3xl mx-auto"
          >
            <h1 className="text-4xl md:text-6xl font-bold text-white mb-6">About Aviation Matrix 360</h1>
            <p className="text-xl text-white/80 leading-relaxed">
              We are the nexus where the precision of current aviation operations meets the ambition of the industry's future.
            </p>
          </motion.div>
        </div>
      </section>

      <section className="py-24 bg-background">
        <div className="container mx-auto px-4 md:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
            <motion.div
              initial={{ opacity: 0, x: -30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              <h2 className="text-sm font-bold text-secondary tracking-widest uppercase mb-3">Our Mission</h2>
              <h3 className="text-3xl md:text-4xl font-bold text-foreground mb-6">Unifying the Aviation Ecosystem</h3>
              <div className="h-1 w-20 bg-secondary mb-8"></div>
              
              <div className="space-y-6 text-lg text-muted-foreground leading-relaxed">
                <p>
                  Aviation Matrix 360 was founded on a singular principle: the aviation industry requires a connected approach to survive and thrive in the modern era. Siloed operations and disconnected educational frameworks leave organizations vulnerable to inefficiency and talent shortages.
                </p>
                <p>
                  We have built a unified ecosystem that connects operational intelligence, professional development, and generational education. By treating these components as interdependent nodes rather than separate entities, we provide aviation organizations with unparalleled resilience and foresight.
                </p>
                <p>
                  From the control room to the classroom, Aviation Matrix 360 delivers the structure, governance, and visibility needed to guide the industry forward.
                </p>
              </div>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
              className="relative rounded-2xl overflow-hidden shadow-2xl aspect-[4/3]"
            >
              <img 
                src="https://images.unsplash.com/photo-1436491865332-7a61a109cc05?q=80&w=2074&auto=format&fit=crop" 
                alt="Aviation Matrix Headquarters" 
                className="w-full h-full object-cover"
              />
              <div className="absolute inset-0 bg-primary/20 mix-blend-overlay"></div>
            </motion.div>
          </div>
        </div>
      </section>

      <section className="py-24 bg-muted/50">
        <div className="container mx-auto px-4 md:px-6">
          <div className="text-center max-w-3xl mx-auto mb-16">
            <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-6">The Three Pillars</h2>
            <div className="h-1 w-20 bg-secondary mx-auto mb-6"></div>
            <p className="text-muted-foreground text-lg">
              Our ecosystem is supported by three foundational pillars, each designed to address a specific phase of the aviation lifecycle.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-card p-8 rounded-xl shadow-lg border border-border">
              <Shield className="h-10 w-10 text-secondary mb-6" />
              <h4 className="text-xl font-bold mb-4">Operational Intelligence</h4>
              <p className="text-muted-foreground">
                Through the Aviation Matrix Platform, we deliver data-driven structure, rigorous governance, and comprehensive visibility for immediate decision support.
              </p>
            </div>
            
            <div className="bg-card p-8 rounded-xl shadow-lg border border-border">
              <Users className="h-10 w-10 text-secondary mb-6" />
              <h4 className="text-xl font-bold mb-4">Professional Development</h4>
              <p className="text-muted-foreground">
                The Aviation Matrix Academy provides continuous, industry-focused learning programs to elevate the operational knowledge of current aviation professionals.
              </p>
            </div>
            
            <div className="bg-card p-8 rounded-xl shadow-lg border border-border">
              <Lightbulb className="h-10 w-10 text-secondary mb-6" />
              <h4 className="text-xl font-bold mb-4">Generational Education</h4>
              <p className="text-muted-foreground">
                Our Kids Aviation Matrix initiative ensures the future of the industry by introducing children to engaging, foundational educational experiences.
              </p>
            </div>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
