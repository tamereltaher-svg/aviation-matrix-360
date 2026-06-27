import { motion } from "framer-motion";
import { Link } from "wouter";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { Button } from "@/components/ui/button";
import { BookOpen, Award, Target, Rocket } from "lucide-react";

export default function Academy() {
  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      <section className="relative pt-32 pb-20 md:pt-48 md:pb-32 bg-primary overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-primary to-primary/80 z-10" />
        <div className="container mx-auto px-4 md:px-6 relative z-20">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="max-w-3xl"
          >
            <div className="inline-block px-3 py-1 rounded-full bg-secondary/20 border border-secondary/30 text-secondary-foreground text-sm font-bold tracking-wider uppercase mb-6">
              Professional Education
            </div>
            <h1 className="text-4xl md:text-6xl font-bold text-white mb-6 leading-tight">
              Aviation Matrix Academy
            </h1>
            <p className="text-xl text-white/80 leading-relaxed mb-8">
              Elevating the industry through professional aviation education, operational knowledge development, and focused learning programs.
            </p>
            <Link href="/contact">
              <Button size="lg" className="bg-secondary text-white hover:bg-secondary/90">
                Enroll Today
              </Button>
            </Link>
          </motion.div>
        </div>
      </section>

      <section className="py-24 bg-background">
        <div className="container mx-auto px-4 md:px-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center mb-24">
            <motion.div
              initial={{ opacity: 0, x: -30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-6">Developing Aviation Leaders</h2>
              <div className="h-1 w-20 bg-secondary mb-8"></div>
              
              <div className="space-y-6 text-lg text-muted-foreground leading-relaxed">
                <p>
                  Technology alone cannot drive the aviation industry forward; it requires highly skilled professionals who understand the intricate balance of operations, safety, and efficiency.
                </p>
                <p>
                  The Aviation Matrix Academy offers rigorous, industry-aligned curricula designed to bridge the gap between theoretical knowledge and practical operational excellence. Our programs are crafted by industry veterans for the next generation of aviation leaders.
                </p>
              </div>
            </motion.div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div className="bg-card p-6 rounded-xl border border-border shadow-sm">
                <BookOpen className="h-8 w-8 text-secondary mb-4" />
                <h4 className="font-bold text-lg mb-2">Curriculum</h4>
                <p className="text-sm text-muted-foreground">Comprehensive modules covering modern aviation operations and management.</p>
              </div>
              <div className="bg-card p-6 rounded-xl border border-border shadow-sm">
                <Target className="h-8 w-8 text-secondary mb-4" />
                <h4 className="font-bold text-lg mb-2">Practical Focus</h4>
                <p className="text-sm text-muted-foreground">Scenario-based learning that directly translates to real-world operations.</p>
              </div>
              <div className="bg-card p-6 rounded-xl border border-border shadow-sm">
                <Award className="h-8 w-8 text-secondary mb-4" />
                <h4 className="font-bold text-lg mb-2">Certification</h4>
                <p className="text-sm text-muted-foreground">Industry-recognized credentials that validate operational expertise.</p>
              </div>
              <div className="bg-card p-6 rounded-xl border border-border shadow-sm">
                <Rocket className="h-8 w-8 text-secondary mb-4" />
                <h4 className="font-bold text-lg mb-2">Innovation</h4>
                <p className="text-sm text-muted-foreground">Exposure to emerging technologies and methodologies shaping the future.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="py-24 bg-primary text-white">
        <div className="container mx-auto px-4 md:px-6">
          <div className="max-w-4xl mx-auto text-center">
            <div className="inline-flex items-center justify-center h-16 w-16 rounded-full bg-white/10 mb-6">
              <Rocket className="h-8 w-8 text-secondary" />
            </div>
            <h2 className="text-3xl md:text-4xl font-bold mb-6">Kids Aviation Matrix</h2>
            <div className="h-1 w-20 bg-secondary mx-auto mb-8"></div>
            <p className="text-xl text-white/80 leading-relaxed mb-10">
              The future of aviation begins long before a professional career starts. Kids Aviation Matrix is our upcoming generational initiative designed to introduce children to the wonders of aerospace through engaging, age-appropriate educational experiences. 
            </p>
            <div className="inline-block px-6 py-3 border border-white/30 rounded-lg text-sm font-medium tracking-wide uppercase">
              Initiative Launching Soon
            </div>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
